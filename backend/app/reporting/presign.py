import boto3
from botocore.exceptions import ClientError

from app.core.config import get_settings
from app.core.logging import get_logger

log = get_logger(__name__)


def get_latest_report_url(expiry_seconds: int = 3600) -> str | None:
    """Return a presigned S3 URL for the most recent Jasper PDF, or None if unavailable."""
    settings = get_settings()
    if not settings.reports_bucket:
        return None

    s3 = boto3.client("s3", region_name=settings.aws_region)
    try:
        resp = s3.list_objects_v2(
            Bucket=settings.reports_bucket,
            Prefix="",
            MaxKeys=100,
        )
        objects = resp.get("Contents", [])
        if not objects:
            return None

        latest = max(objects, key=lambda o: o["LastModified"])
        url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.reports_bucket, "Key": latest["Key"]},
            ExpiresIn=expiry_seconds,
        )
        return url
    except ClientError as exc:
        log.warning("presign_failed", error=str(exc))
        return None
