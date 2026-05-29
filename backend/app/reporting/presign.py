from pathlib import Path

import structlog

from app.core.config import get_settings

log = structlog.get_logger(__name__)

_LOCAL_REPORTS_DIR = Path("/reports")


def get_latest_report_url(expiry_seconds: int = 3600) -> str | None:
    """Return a URL to the latest report PDF.

    Production (REPORTS_BUCKET set): generates an S3 presigned GET URL.
    Local dev (no bucket): returns the same-origin path served by the backend.
    """
    settings = get_settings()

    if settings.reports_bucket:
        import boto3
        from botocore.exceptions import ClientError

        s3 = boto3.client("s3", region_name=settings.aws_region)
        try:
            resp = s3.list_objects_v2(Bucket=settings.reports_bucket, MaxKeys=100)
            objects = resp.get("Contents", [])
            if not objects:
                return None
            latest = max(objects, key=lambda o: o["LastModified"])
            return s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": settings.reports_bucket, "Key": latest["Key"]},
                ExpiresIn=expiry_seconds,
            )
        except ClientError as exc:
            log.warning("presign_failed", error=str(exc))
            return None

    # Local dev: serve from the /reports volume mount
    if _LOCAL_REPORTS_DIR.exists() and sorted(_LOCAL_REPORTS_DIR.glob("*.pdf")):
        return "/api/reports/latest"
    return None
