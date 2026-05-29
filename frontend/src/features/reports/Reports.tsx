import { useQuery } from "@tanstack/react-query";
import { ordersApi } from "../../api/orders";

export function Reports() {
  const { data: reportUrl, isLoading, isError } = useQuery({
    queryKey: ["report-url"],
    queryFn: ordersApi.latestReportUrl,
    retry: false,
  });

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Monthly Report</h1>
      <p className="text-sm text-gray-500 mb-4">
        Generated daily at 06:00 UTC by the report runner. Run{" "}
        <code>make report</code> locally to produce a PDF on demand.
      </p>

      {isLoading && <div className="text-gray-500">Loading report…</div>}

      {isError && (
        <div className="bg-yellow-50 border border-yellow-200 text-yellow-800 text-sm px-4 py-3 rounded">
          No report available yet. Run <code>make report</code> to generate one.
        </div>
      )}

      {reportUrl && (
        <>
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
        </>
      )}
    </div>
  );
}
