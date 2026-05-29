export function Reports() {
  const reportUrl = "/api/reports/latest";

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Monthly Report</h1>
      <p className="text-sm text-gray-500 mb-4">
        Generated on demand by the Jasper report runner. Run <code>make report</code> locally to
        produce a PDF, then refresh this page.
      </p>

      <div className="flex items-center gap-3 mb-4">
        <a
          href={reportUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center px-4 py-2 bg-brand-600 text-white rounded hover:bg-brand-700 text-sm font-medium transition-colors"
        >
          Open PDF in new tab
        </a>
        <a
          href={reportUrl}
          download
          className="inline-flex items-center px-4 py-2 border border-gray-300 text-gray-700 rounded hover:bg-gray-50 text-sm font-medium transition-colors"
        >
          Download PDF
        </a>
      </div>

      <iframe
        src={reportUrl}
        className="w-full border border-gray-300 rounded-lg shadow-sm"
        style={{ height: "80vh" }}
        title="Monthly orders report"
      />
    </div>
  );
}
