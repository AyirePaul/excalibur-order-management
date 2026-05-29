import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, it, expect } from "vitest";
import { Reports } from "../src/features/reports/Reports";

function renderWithRouter(ui: React.ReactElement) {
  return render(<MemoryRouter>{ui}</MemoryRouter>);
}

describe("Reports", () => {
  it("renders heading", () => {
    renderWithRouter(<Reports />);
    expect(screen.getByRole("heading", { name: /monthly report/i })).toBeInTheDocument();
  });

  it("embeds iframe pointing to backend report endpoint", () => {
    renderWithRouter(<Reports />);
    const iframe = screen.getByTitle(/monthly orders report/i);
    expect(iframe).toBeInTheDocument();
    expect(iframe).toHaveAttribute("src", "/api/reports/latest");
  });

  it("shows open and download links", () => {
    renderWithRouter(<Reports />);
    expect(screen.getByText(/open pdf in new tab/i)).toBeInTheDocument();
    expect(screen.getByText(/download pdf/i)).toBeInTheDocument();
  });
});
