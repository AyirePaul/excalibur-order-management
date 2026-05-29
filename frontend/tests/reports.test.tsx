import { render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router-dom";
import { vi, describe, it, expect } from "vitest";
import { Reports } from "../src/features/reports/Reports";

vi.mock("../src/api/orders", () => ({
  ordersApi: {
    latestReportUrl: vi.fn(),
  },
}));

async function getApi() {
  const { ordersApi } = await import("../src/api/orders");
  return ordersApi;
}

function renderWithProviders(ui: React.ReactElement) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter>{ui}</MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("Reports", () => {
  it("renders heading", () => {
    renderWithProviders(<Reports />);
    expect(screen.getByRole("heading", { name: /monthly report/i })).toBeInTheDocument();
  });

  it("shows iframe when URL available", async () => {
    const api = await getApi();
    (api.latestReportUrl as ReturnType<typeof vi.fn>).mockResolvedValue(
      "https://s3.example.com/2026-05-29.pdf?X-Amz-Signature=abc",
    );
    renderWithProviders(<Reports />);
    await waitFor(() => {
      expect(screen.getByTitle(/monthly orders report/i)).toBeInTheDocument();
    });
  });

  it("shows no-report message on 404", async () => {
    const api = await getApi();
    (api.latestReportUrl as ReturnType<typeof vi.fn>).mockRejectedValue(
      new Error("404"),
    );
    renderWithProviders(<Reports />);
    await waitFor(() =>
      expect(screen.getByText(/no report available yet/i)).toBeInTheDocument(),
    );
  });
});
