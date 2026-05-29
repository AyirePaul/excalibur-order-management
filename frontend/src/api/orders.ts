import { apiClient } from "./client";

export interface Order {
  order_id: string;
  order_date: string;
  order_amount: string;
  order_description: string;
}

export interface CombineRequest {
  dateFrom?: string;
  dateTo?: string;
  amountOp: "GT" | "LT" | "BETWEEN";
  amountValue: number;
  amountValue2?: number;
  descriptionContains?: string;
}

export interface CombineResponse {
  items: Order[];
  count: number;
}

export const ordersApi = {
  list: () => apiClient.get<Order[]>("/orders").then((r) => r.data),

  get: (id: string) => apiClient.get<Order>(`/orders/${id}`).then((r) => r.data),

  create: (payload: Omit<Order, "order_id">) =>
    apiClient.post<Order>("/orders", payload).then((r) => r.data),

  update: (id: string, payload: Partial<Omit<Order, "order_id">>) =>
    apiClient.put<Order>(`/orders/${id}`, payload).then((r) => r.data),

  delete: (id: string) => apiClient.delete(`/orders/${id}`),

  combine: (req: CombineRequest) =>
    apiClient.post<CombineResponse>("/orders/combine", req).then((r) => r.data),

  latestReportUrl: () =>
    apiClient.get<{ url: string }>("/api/reports/latest-url").then((r) => r.data.url),

  exportCsvUrl: (req: CombineRequest) => {
    const params = new URLSearchParams({
      amountOp: req.amountOp,
      amountValue: String(req.amountValue),
      ...(req.dateFrom && { dateFrom: req.dateFrom }),
      ...(req.dateTo && { dateTo: req.dateTo }),
      ...(req.amountValue2 !== undefined && { amountValue2: String(req.amountValue2) }),
      ...(req.descriptionContains && { descriptionContains: req.descriptionContains }),
    });
    return `${import.meta.env.VITE_API_BASE_URL ?? ""}/orders/export.csv?${params}`;
  },

  latestReportUrl: () =>
    apiClient.get<{ url: string | null }>("/api/reports/latest-url").then((r) => r.data.url),
};
