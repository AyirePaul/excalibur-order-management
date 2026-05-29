import time
from typing import Annotated

import httpx
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import ExpiredSignatureError, JWTError, jwt

from app.core.config import get_settings

_bearer = HTTPBearer(auto_error=False)

# JWKS cache with 1-hour TTL and on-kid-miss refresh to survive key rotation.
_jwks_cache: dict | None = None
_jwks_fetched_at: float = 0.0
_JWKS_TTL = 3600.0


def _get_jwks(user_pool_id: str, region: str) -> dict:
    global _jwks_cache, _jwks_fetched_at
    now = time.monotonic()
    if _jwks_cache is None or (now - _jwks_fetched_at) >= _JWKS_TTL:
        url = f"https://cognito-idp.{region}.amazonaws.com/{user_pool_id}/.well-known/jwks.json"
        resp = httpx.get(url, timeout=10)
        resp.raise_for_status()
        _jwks_cache = resp.json()
        _jwks_fetched_at = now
    return _jwks_cache


def _decode_token(token: str) -> dict:
    settings = get_settings()
    jwks = _get_jwks(settings.cognito_user_pool_id, settings.cognito_region)
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Malformed token") from exc

    key = next((k for k in jwks["keys"] if k["kid"] == header.get("kid")), None)
    if key is None:
        # kid not found — Cognito may have rotated keys; force one refresh and retry
        global _jwks_cache
        _jwks_cache = None
        jwks = _get_jwks(settings.cognito_user_pool_id, settings.cognito_region)
        key = next((k for k in jwks["keys"] if k["kid"] == header.get("kid")), None)
    if key is None:
        raise HTTPException(status_code=401, detail="Unknown token key")

    try:
        return jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=settings.cognito_app_client_id,
            options={"verify_at_hash": False},
        )
    except ExpiredSignatureError as exc:
        raise HTTPException(status_code=401, detail="Token expired") from exc
    except JWTError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}") from exc


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> dict:
    settings = get_settings()
    # Local dev bypass when Cognito is not configured
    if not settings.cognito_user_pool_id:
        return {"sub": "local-dev", "cognito:groups": ["editor"], "email": "dev@local"}

    if credentials is None:
        raise HTTPException(status_code=401, detail="Not authenticated")

    return _decode_token(credentials.credentials)


CurrentUser = Annotated[dict, Depends(get_current_user)]


def require_editor(user: CurrentUser) -> dict:
    groups = user.get("cognito:groups", [])
    if "editor" not in groups:
        raise HTTPException(status_code=403, detail="Editor role required")
    return user


def require_viewer(user: CurrentUser) -> dict:
    groups = user.get("cognito:groups", [])
    if not any(g in groups for g in ("viewer", "editor")):
        raise HTTPException(status_code=403, detail="Viewer role required")
    return user


EditorRequired = Annotated[dict, Depends(require_editor)]
ViewerRequired = Annotated[dict, Depends(require_viewer)]
