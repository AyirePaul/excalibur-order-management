import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router-dom";
import { vi, describe, it, expect, beforeEach } from "vitest";
import { Combine } from "../src/features/combine/Combine";

const mockCombine = vi.fn().mockResolvedValue({
  items: [
    {
      order_id: "ccc",
      order_date: "2025-03-10",
      order_amount: "320.00",
      order_description: "Industrial widget pack",
    },
  ],
  count: 1,
});

vi.mock("../src/api/orders", () => ({
  ordersApi: {
    combine: mockCombine,
    exportCsvUrl: vi.fn().mockReturnValue("http://localhost:8000/orders/export.csv?amountOp=GT&amountValue=0"),
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

describe("Combine", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders the filter form", () => {
    renderWithProviders(<Combine />);
    expect(screen.getByRole("button", { name: /combine/i })).toBeInTheDocument();
    expect(screen.getByLabelText(/date from/i)).toBeInTheDocument();
  });

  it("shows BETWEEN field only when BETWEEN selected", async () => {
    const user = userEvent.setup();
    renderWithProviders(<Combine />);

    expect(screen.queryByLabelText(/amount.*max/i)).not.toBeInTheDocument();

    const select = screen.getByRole("combobox");
    await user.selectOptions(select, "BETWEEN");

    expect(screen.getByLabelText(/amount.*max/i)).toBeInTheDocument();
  });

  it("calls combine API and displays results", async () => {
    const user = userEvent.setup();
    renderWithProviders(<Combine />);

    await user.click(screen.getByRole("button", { name: /combine/i }));

    await waitFor(() =>
      expect(screen.getByText("Industrial widget pack")).toBeInTheDocument(),
    );
    expect(mockCombine).toHaveBeenCalledOnce();
  });

  it("shows Export CSV link after results load", async () => {
    const user = userEvent.setup();
    renderWithProviders(<Combine />);
    await user.click(screen.getByRole("button", { name: /combine/i }));

    await waitFor(() => expect(screen.getByText("Export CSV")).toBeInTheDocument());
  });
});
