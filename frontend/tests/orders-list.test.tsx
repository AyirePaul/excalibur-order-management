import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router-dom";
import { vi, describe, it, expect, beforeEach } from "vitest";
import { OrdersList } from "../src/features/orders-list/OrdersList";

// Mock the API
vi.mock("../src/api/orders", () => ({
  ordersApi: {
    list: vi.fn().mockResolvedValue([
      {
        order_id: "aaa",
        order_date: "2025-01-15",
        order_amount: "150.00",
        order_description: "Widget A",
      },
      {
        order_id: "bbb",
        order_date: "2025-02-20",
        order_amount: "8.50",
        order_description: "Sticky notes",
      },
    ]),
    delete: vi.fn().mockResolvedValue({}),
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

describe("OrdersList", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("shows a loading state initially", () => {
    renderWithProviders(<OrdersList />);
    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });

  it("renders orders in table view after load", async () => {
    renderWithProviders(<OrdersList />);
    await waitFor(() => expect(screen.getByText("Widget A")).toBeInTheDocument());
    expect(screen.getByText("Sticky notes")).toBeInTheDocument();
  });

  it("shows dollar amounts formatted", async () => {
    renderWithProviders(<OrdersList />);
    await waitFor(() => expect(screen.getByText("$150.00")).toBeInTheDocument());
    expect(screen.getByText("$8.50")).toBeInTheDocument();
  });

  it("toggles to card view when Cards button clicked", async () => {
    const user = userEvent.setup();
    renderWithProviders(<OrdersList />);
    await waitFor(() => expect(screen.getByText("Widget A")).toBeInTheDocument());

    const cardsBtn = screen.getByRole("button", { name: /cards/i });
    await user.click(cardsBtn);

    // In card view, amounts are shown with $ prefix prominently
    await waitFor(() =>
      expect(screen.getAllByText("$150.00").length).toBeGreaterThanOrEqual(1),
    );
  });

  it("Table and Cards buttons have distinct active styles", async () => {
    const user = userEvent.setup();
    renderWithProviders(<OrdersList />);
    await waitFor(() => expect(screen.getByText("Widget A")).toBeInTheDocument());

    const tableBtn = screen.getByRole("button", { name: /table/i });
    const cardsBtn = screen.getByRole("button", { name: /cards/i });

    // Table is active by default
    expect(tableBtn.className).toContain("bg-brand-600");
    expect(cardsBtn.className).not.toContain("bg-brand-600");

    await user.click(cardsBtn);
    expect(cardsBtn.className).toContain("bg-amber-500");
    expect(tableBtn.className).not.toContain("bg-brand-600");
  });

  it("shows new order button for editors", async () => {
    renderWithProviders(<OrdersList />);
    await waitFor(() => expect(screen.getByText("Widget A")).toBeInTheDocument());
    expect(screen.getByRole("button", { name: /new order/i })).toBeInTheDocument();
  });
});
