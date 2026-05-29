import { lazy, Suspense } from "react";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { App } from "./App";

// Lazy-loaded routes for code splitting
const OrdersList = lazy(() =>
  import("./features/orders-list/OrdersList").then((m) => ({ default: m.OrdersList })),
);
const OrdersEdit = lazy(() =>
  import("./features/orders-edit/OrdersEdit").then((m) => ({ default: m.OrdersEdit })),
);
const OrdersNew = lazy(() =>
  import("./features/orders-edit/OrdersEdit").then((m) => ({ default: m.OrdersNew })),
);
const Combine = lazy(() =>
  import("./features/combine/Combine").then((m) => ({ default: m.Combine })),
);
const Reports = lazy(() =>
  import("./features/reports/Reports").then((m) => ({ default: m.Reports })),
);

const Loading = () => (
  <div className="flex items-center justify-center h-48 text-gray-500">Loading…</div>
);

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<App />}>
          <Route
            index
            element={
              <Suspense fallback={<Loading />}>
                <OrdersList />
              </Suspense>
            }
          />
          <Route
            path="orders/new"
            element={
              <Suspense fallback={<Loading />}>
                <OrdersNew />
              </Suspense>
            }
          />
          <Route
            path="orders/:id"
            element={
              <Suspense fallback={<Loading />}>
                <OrdersEdit />
              </Suspense>
            }
          />
          <Route
            path="combine"
            element={
              <Suspense fallback={<Loading />}>
                <Combine />
              </Suspense>
            }
          />
          <Route
            path="reports"
            element={
              <Suspense fallback={<Loading />}>
                <Reports />
              </Suspense>
            }
          />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
