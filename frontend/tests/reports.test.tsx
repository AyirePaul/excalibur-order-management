import { render, screen, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router-dom";
import { vi, describe, it, expect } from "vitest";
import { Reports } from "../src/features/reports/Reports";

vi.mock("../src/api/orders", () => ({
  ordersApi: {
    latestReportUrl: vi.fn().mockResolvedValue("https://s3.example.com/report.pdf?X-Amz-Signature=abc"),
  },
}));

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
    renderWithProviders(<Reports />);
    await waitFor(() => {
      const iframe = screen.getByTitle(/monthly orders report/i);
      expect(iframe).toBeInTheDocument();
    });
  });

  it("shows no-report message when URL is null", async () => {
    const { ordersApi } = await import("../src/api/orders");
    (ordersApi.latestReportUrl as ReturnType<typeof vi.fn>).mockResolvedValueOnce(null);

    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <Reports />
        </MemoryRouter>
      </QueryClientProvider>,
    );

    await waitFor(() =>
      expect(screen.getByText(/no report has been generated/i)).toBeInTheDocument(),
    );
  });
});
