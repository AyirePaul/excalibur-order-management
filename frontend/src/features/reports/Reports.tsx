import { useQuery } from "@tanstack/react-query";
import { ordersApi } from "../../api/orders";

export function Reports() {
  const { data: url, isLoading, isError } = useQuery({
    queryKey: ["report-url"],
    queryFn: ordersApi.latestReportUrl,
    refetchInterval: 60_000,
  });

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Monthly Report</h1>
      <p className="text-sm text-gray-500 mb-4">
        Generated daily at 06:00 UTC by the Jasper report runner. The presigned URL expires in 1 hour.
      </p>

      {isLoading && <div className="text-gray-500">Loading…</div>}

      {isError && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-3 rounded">
          Failed to fetch report URL.
        </div>
      )}

      {!isLoading && !isError && !url && (
        <div className="bg-yellow-50 border border-yellow-200 text-yellow-800 text-sm px-4 py-3 rounded">
          No report has been generated yet. The EventBridge schedule runs daily at 06:00 UTC.
        </div>
      )}

      {url && (
        <div>
          <div className="flex items-center gap-3 mb-4">
            <a
              href={url}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center px-4 py-2 bg-brand-600 text-white rounded hover:bg-brand-700 text-sm font-medium transition-colors"
            >
              Open PDF in new tab
            </a>
            <a
              href={url}
              download
              className="inline-flex items-center px-4 py-2 border border-gray-300 text-gray-700 rounded hover:bg-gray-50 text-sm font-medium transition-colors"
            >
              Download PDF
            </a>
          </div>

          <iframe
            src={url}
            className="w-full border border-gray-300 rounded-lg shadow-sm"
            style={{ height: "80vh" }}
            title="Monthly orders report"
          />
        </div>
      )}
    </div>
  );
}
