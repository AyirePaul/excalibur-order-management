import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ordersApi, type Order } from "../../api/orders";
import { Button } from "../../components/Button";

type ViewMode = "table" | "card";

export function OrdersList() {
  const [view, setView] = useState<ViewMode>("table");
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data: orders = [], isLoading, isError } = useQuery({
    queryKey: ["orders"],
    queryFn: ordersApi.list,
  });

  const deleteMutation = useMutation({
    mutationFn: ordersApi.delete,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["orders"] }),
  });

  if (isLoading) return <div className="text-gray-500">Loading orders…</div>;
  if (isError) return <div className="text-red-600">Failed to load orders.</div>;

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Orders</h1>

        <div className="flex items-center gap-3">
          {/* Tab/Card toggle — two visibly distinct CSS treatments */}
          <div className="inline-flex rounded-md shadow-sm border border-gray-300 overflow-hidden">
            <button
              onClick={() => setView("table")}
              className={`px-4 py-2 text-sm font-medium transition-colors ${
                view === "table"
                  ? "bg-brand-600 text-white"
                  : "bg-white text-gray-700 hover:bg-gray-50"
              }`}
              aria-pressed={view === "table"}
            >
              Table
            </button>
            <button
              onClick={() => setView("card")}
              className={`px-4 py-2 text-sm font-medium transition-colors border-l border-gray-300 ${
                view === "card"
                  ? "bg-amber-500 text-white"
                  : "bg-white text-gray-700 hover:bg-gray-50"
              }`}
              aria-pressed={view === "card"}
            >
              Cards
            </button>
          </div>

          <Button onClick={() => navigate("/orders/new")}>+ New Order</Button>
        </div>
      </div>

      {orders.length === 0 && (
        <p className="text-gray-500 text-center py-12">No orders yet. Create one to get started.</p>
      )}

      {/* ── Table view ─────────────────────────────────────────────────── */}
      {view === "table" && orders.length > 0 && (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                {["Date", "Amount", "Description", ""].map((h) => (
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
              {orders.map((order) => (
                <TableRow
                  key={order.order_id}
                  order={order}
                  onEdit={() => navigate(`/orders/${order.order_id}`)}
                  onDelete={() => deleteMutation.mutate(order.order_id)}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ── Card view — distinctly different layout/color/spacing ────── */}
      {view === "card" && orders.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {orders.map((order) => (
            <OrderCard
              key={order.order_id}
              order={order}
              onEdit={() => navigate(`/orders/${order.order_id}`)}
              onDelete={() => deleteMutation.mutate(order.order_id)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ── Sub-components ────────────────────────────────────────────────────────────

function TableRow({
  order,
  onEdit,
  onDelete,
}: {
  order: Order;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <tr
      className="hover:bg-gray-50 transition-colors cursor-pointer"
      onClick={onEdit}
    >
      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700">{order.order_date}</td>
      <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900">
        ${Number(order.order_amount).toFixed(2)}
      </td>
      <td className="px-6 py-4 text-sm text-gray-600 max-w-xs truncate">{order.order_description}</td>
      <td className="px-6 py-4 whitespace-nowrap text-right text-sm">
        <button
          className="text-red-500 hover:text-red-700 ml-4"
          onClick={(e) => {
            e.stopPropagation();
            onDelete();
          }}
        >
          Delete
        </button>
      </td>
    </tr>
  );
}

function OrderCard({
  order,
  onEdit,
  onDelete,
}: {
  order: Order;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <div className="bg-gradient-to-br from-amber-50 to-orange-50 border border-amber-200 rounded-xl p-5 shadow-sm hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-3">
        <span className="text-2xl font-bold text-amber-700">
          ${Number(order.order_amount).toFixed(2)}
        </span>
        <span className="text-xs bg-amber-100 text-amber-800 px-2 py-1 rounded-full font-medium">
          {order.order_date}
        </span>
      </div>
      <p className="text-gray-700 text-sm leading-relaxed mb-4 line-clamp-2">
        {order.order_description}
      </p>
      <div className="flex gap-2 mt-auto">
        <button
          onClick={onEdit}
          className="flex-1 text-center text-sm py-1.5 bg-amber-500 text-white rounded-lg hover:bg-amber-600 transition-colors"
        >
          Edit
        </button>
        <button
          onClick={onDelete}
          className="flex-1 text-center text-sm py-1.5 border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
        >
          Delete
        </button>
      </div>
    </div>
  );
}
