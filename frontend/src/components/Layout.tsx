import type { ReactNode } from "react";
import { Link, NavLink } from "react-router-dom";

interface Props {
  children: ReactNode;
}

export function Layout({ children }: Props) {
  const navClass = ({ isActive }: { isActive: boolean }) =>
    `px-3 py-2 rounded text-sm font-medium transition-colors ${
      isActive ? "bg-brand-700 text-white" : "text-blue-100 hover:bg-brand-600 hover:text-white"
    }`;

  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-brand-900 text-white shadow-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between h-16">
          <Link to="/" className="text-lg font-bold tracking-tight text-white hover:text-blue-200">
            Order Management
          </Link>

          <nav className="flex items-center gap-1">
            <NavLink to="/" end className={navClass}>
              Orders
            </NavLink>
            <NavLink to="/combine" className={navClass}>
              Combine
            </NavLink>
            <NavLink to="/reports" className={navClass}>
              Reports
            </NavLink>
            <NavLink to="/orders/new" className={navClass}>
              + New Order
            </NavLink>
          </nav>
        </div>
      </header>

      <main className="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>

      <footer className="border-t border-gray-200 text-center text-xs text-gray-400 py-4">
        Order Management — Excalibur Assignment Tier 3
      </footer>
    </div>
  );
}
