import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { ordersApi, type CombineRequest, type Order } from "../../api/orders";
import { Button } from "../../components/Button";

interface FormValues {
  dateFrom: string;
  dateTo: string;
  amountOp: "GT" | "LT" | "BETWEEN";
  amountValue: string;
  amountValue2: string;
  descriptionContains: string;
}

export function Combine() {
  const [results, setResults] = useState<Order[]>([]);
  const [csvReq, setCsvReq] = useState<CombineRequest | null>(null);

  const { register, handleSubmit, watch } = useForm<FormValues>({
    defaultValues: { amountOp: "GT", amountValue: "0" },
  });

  const amountOp = watch("amountOp");

  const combineMutation = useMutation({
    mutationFn: ordersApi.combine,
    onSuccess: (data) => setResults(data.items),
  });

  const onSubmit = (vals: FormValues) => {
    const req: CombineRequest = {
      amountOp: vals.amountOp,
      amountValue: Number(vals.amountValue),
      ...(vals.dateFrom && { dateFrom: vals.dateFrom }),
      ...(vals.dateTo && { dateTo: vals.dateTo }),
      ...(vals.amountOp === "BETWEEN" &&
        vals.amountValue2 && { amountValue2: Number(vals.amountValue2) }),
      ...(vals.descriptionContains && { descriptionContains: vals.descriptionContains }),
    };
    setCsvReq(req);
    combineMutation.mutate(req);
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Combine Orders</h1>

      {/* Filter form */}
      <form
        onSubmit={handleSubmit(onSubmit)}
        className="bg-white rounded-lg shadow p-6 mb-8 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
      >
        <div>
          <label htmlFor="dateFrom" className="block text-sm font-medium text-gray-700 mb-1">Date From</label>
          <input
            id="dateFrom"
            type="date"
            {...register("dateFrom")}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label htmlFor="dateTo" className="block text-sm font-medium text-gray-700 mb-1">Date To</label>
          <input
            id="dateTo"
            type="date"
            {...register("dateTo")}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label htmlFor="amountOp" className="block text-sm font-medium text-gray-700 mb-1">Amount Filter</label>
          <select
            id="amountOp"
            {...register("amountOp")}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          >
            <option value="GT">Greater than</option>
            <option value="LT">Less than</option>
            <option value="BETWEEN">Between</option>
          </select>
        </div>

        <div>
          <label htmlFor="amountValue" className="block text-sm font-medium text-gray-700 mb-1">
            {amountOp === "BETWEEN" ? "Amount (min)" : "Amount"}
          </label>
          <input
            id="amountValue"
            type="number"
            step="0.01"
            {...register("amountValue")}
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          />
        </div>

        {amountOp === "BETWEEN" && (
          <div>
            <label htmlFor="amountValue2" className="block text-sm font-medium text-gray-700 mb-1">Amount (max)</label>
            <input
              id="amountValue2"
              type="number"
              step="0.01"
              {...register("amountValue2")}
              className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
            />
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Description Contains
          </label>
          <input
            type="text"
            {...register("descriptionContains")}
            placeholder="widget…"
            className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
          />
        </div>

        <div className="sm:col-span-2 lg:col-span-3 flex items-center gap-3 pt-2">
          <Button type="submit" disabled={combineMutation.isPending}>
            {combineMutation.isPending ? "Running…" : "Combine"}
          </Button>

          {csvReq && results.length > 0 && (
            <a
              href={ordersApi.exportCsvUrl(csvReq)}
              download="orders.csv"
              className="inline-flex items-center px-4 py-2 rounded-md text-sm font-medium border border-gray-300 text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Export CSV
            </a>
          )}
        </div>
      </form>

      {/* Results table */}
      {combineMutation.isSuccess && (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
            <h2 className="text-base font-semibold text-gray-800">
              Results — {results.length} row{results.length !== 1 ? "s" : ""}
            </h2>
          </div>

          {results.length === 0 ? (
            <p className="px-6 py-8 text-gray-500 text-sm text-center">
              No orders match the selected filters.
            </p>
          ) : (
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  {["Date", "Amount", "Description"].map((h) => (
                    <th
                      key={h}
                      className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider"
                    >
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-100">
                {results.map((row) => (
                  <tr key={row.order_id} className="hover:bg-gray-50">
                    <td className="px-6 py-3 text-sm text-gray-700">{row.order_date}</td>
                    <td className="px-6 py-3 text-sm font-semibold text-gray-900">
                      ${Number(row.order_amount).toFixed(2)}
                    </td>
                    <td className="px-6 py-3 text-sm text-gray-600">{row.order_description}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}
