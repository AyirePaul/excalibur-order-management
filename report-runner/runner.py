"""
Report runner: connects to Postgres, runs JasperStarter against orders_by_month.jrxml,
writes PDF to OUTPUT_DIR. Run locally via `make report`; invoke on-demand in ECS
by running this container with the right environment variables.
"""

import os
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

import boto3


def _get_db_url() -> str:
    """Resolve DB connection as a JDBC URL for JasperStarter.

    In ECS: DATABASE_URL is injected from Secrets Manager (SQLAlchemy-style URL).
    Locally: falls back to individual POSTGRES_* environment variables.
    """
    from urllib.parse import urlparse

    database_url = os.environ.get("DATABASE_URL")
    if database_url:
        # Strip SQLAlchemy driver prefix, e.g. postgresql+psycopg:// → postgresql://
        clean = database_url.replace("postgresql+psycopg", "postgresql").replace("postgresql+psycopg2", "postgresql")
        p = urlparse(clean)
        host = p.hostname
        port = p.port or 5432
        user = p.username
        pw = p.password
        dbname = p.path.lstrip("/").split("?")[0]
        return f"jdbc:postgresql://{host}:{port}/{dbname}?user={user}&password={pw}&ssl=true&sslmode=require"

    # Local docker-compose
    host = os.environ.get("POSTGRES_HOST", "localhost")
    port = os.environ.get("POSTGRES_PORT", "5432")
    user = os.environ.get("POSTGRES_USER", "orders")
    pw = os.environ.get("POSTGRES_PASSWORD", "orders")
    dbname = os.environ.get("POSTGRES_DB", "orders")
    return f"jdbc:postgresql://{host}:{port}/{dbname}?user={user}&password={pw}"


def run_report(output_path: Path) -> None:
    today = date.today()
    date_from = today.replace(day=1).isoformat()
    date_to = (today.replace(day=1) + timedelta(days=32)).replace(day=1) - timedelta(days=1)

    db_url = _get_db_url()
    jrxml = Path(__file__).parent / "reports" / "orders_by_month.jrxml"

    cmd = [
        "jasperstarter",
        "process",
        str(jrxml),
        "-o", str(output_path.with_suffix("")),
        "-f", "pdf",
        "-t", "generic",
        "--db-url", db_url,
        "--db-driver", "org.postgresql.Driver",
        "-P",
        f"P_DATE_FROM={date_from}",
        f"P_DATE_TO={date_to.isoformat()}",
        "P_AMOUNT_MIN=0",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"jasperstarter stderr:\n{result.stderr}", file=sys.stderr)
        raise RuntimeError(f"jasperstarter failed with code {result.returncode}")
    print(result.stdout)


def upload_to_s3(pdf_path: Path) -> str:
    bucket = os.environ.get("REPORTS_BUCKET")
    if not bucket:
        print("REPORTS_BUCKET not set — skipping S3 upload (local mode)", file=sys.stderr)
        return str(pdf_path)

    key = f"{date.today().isoformat()}.pdf"
    s3 = boto3.client("s3", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    s3.upload_file(str(pdf_path), bucket, key, ExtraArgs={"ContentType": "application/pdf"})
    s3_url = f"s3://{bucket}/{key}"
    print(f"Uploaded report to {s3_url}")
    return s3_url


def main() -> None:
    output_dir = Path(os.environ.get("OUTPUT_DIR", "/tmp"))
    output_dir.mkdir(parents=True, exist_ok=True)
    pdf_path = output_dir / f"{date.today().isoformat()}.pdf"

    print(f"Generating report → {pdf_path}")
    run_report(pdf_path)

    if not pdf_path.exists():
        raise FileNotFoundError(f"Expected PDF not found: {pdf_path}")

    upload_to_s3(pdf_path)
    print("Done.")


if __name__ == "__main__":
    main()
