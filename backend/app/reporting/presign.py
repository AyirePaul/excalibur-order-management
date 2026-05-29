from pathlib import Path

REPORTS_DIR = Path("/reports")


def get_latest_report_url() -> str | None:
    """Return the same-origin URL for the latest report PDF, or None if none exist."""
    if not REPORTS_DIR.exists():
        return None
    pdfs = sorted(REPORTS_DIR.glob("*.pdf"))
    if not pdfs:
        return None
    return "/api/reports/latest"
