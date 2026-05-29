import { lazy, Suspense } from "react";
import { BrowserRouter, Route, Routes } from "react-router-dom";
import { App } from "./App";
import { AuthCallback } from "./auth/AuthCallback";
import { ProtectedRoute } from "./auth/ProtectedRoute";

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
        <Route path="/auth/callback" element={<AuthCallback />} />
        <Route element={<App />}>
          <Route
            index
            element={
              <ProtectedRoute>
                <Suspense fallback={<Loading />}>
                  <OrdersList />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="orders/new"
            element={
              <ProtectedRoute requireEditor>
                <Suspense fallback={<Loading />}>
                  <OrdersNew />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="orders/:id"
            element={
              <ProtectedRoute requireEditor>
                <Suspense fallback={<Loading />}>
                  <OrdersEdit />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="combine"
            element={
              <ProtectedRoute>
                <Suspense fallback={<Loading />}>
                  <Combine />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="reports"
            element={
              <ProtectedRoute>
                <Suspense fallback={<Loading />}>
                  <Reports />
                </Suspense>
              </ProtectedRoute>
            }
          />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
