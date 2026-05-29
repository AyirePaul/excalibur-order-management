import { useEffect } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { ordersApi } from "../../api/orders";
import { Button } from "../../components/Button";

interface FormValues {
  order_date: string;
  order_amount: string;
  order_description: string;
}

// ── Create form ───────────────────────────────────────────────────────────────

export function OrdersNew() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>();

  const createMutation = useMutation({
    mutationFn: (data: FormValues) =>
      ordersApi.create({
        order_date: data.order_date,
        order_amount: data.order_amount,
        order_description: data.order_description,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["orders"] });
      navigate("/");
    },
  });

  return (
    <div className="max-w-lg mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">New Order</h1>
      <OrderForm
        errors={errors}
        isSubmitting={isSubmitting}
        onSubmit={handleSubmit((d) => createMutation.mutateAsync(d))}
        onCancel={() => navigate("/")}
        register={register}
        submitLabel="Create Order"
        serverError={createMutation.error?.message}
      />
    </div>
  );
}

// ── Edit form ─────────────────────────────────────────────────────────────────

export function OrdersEdit() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data: order, isLoading } = useQuery({
    queryKey: ["order", id],
    queryFn: () => ordersApi.get(id!),
    enabled: !!id,
  });

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>();

  useEffect(() => {
    if (order) {
      reset({
        order_date: order.order_date,
        order_amount: order.order_amount,
        order_description: order.order_description,
      });
    }
  }, [order, reset]);

  const updateMutation = useMutation({
    mutationFn: (data: FormValues) =>
      ordersApi.update(id!, {
        order_date: data.order_date,
        order_amount: data.order_amount,
        order_description: data.order_description,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["orders"] });
      queryClient.invalidateQueries({ queryKey: ["order", id] });
      navigate("/");
    },
  });

  if (isLoading) return <div className="text-gray-500">Loading…</div>;

  return (
    <div className="max-w-lg mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Edit Order</h1>
      <OrderForm
        errors={errors}
        isSubmitting={isSubmitting}
        onSubmit={handleSubmit((d) => updateMutation.mutateAsync(d))}
        onCancel={() => navigate("/")}
        register={register}
        submitLabel="Save Changes"
        serverError={updateMutation.error?.message}
      />
    </div>
  );
}

// ── Shared form component ─────────────────────────────────────────────────────

interface OrderFormProps {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  register: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  errors: any;
  isSubmitting: boolean;
  onSubmit: () => void;
  onCancel: () => void;
  submitLabel: string;
  serverError?: string;
}

function OrderForm({
  register,
  errors,
  isSubmitting,
  onSubmit,
  onCancel,
  submitLabel,
  serverError,
}: OrderFormProps) {
  return (
    <form onSubmit={onSubmit} className="bg-white rounded-lg shadow p-6 space-y-5" noValidate>
      {serverError && (
        <div className="bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-3 rounded">
          {serverError}
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Order Date <span className="text-red-500">*</span>
        </label>
        <input
          type="date"
          {...register("order_date", { required: "Date is required" })}
          className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 ${
            errors.order_date ? "border-red-500" : "border-gray-300"
          }`}
        />
        {errors.order_date && (
          <p className="mt-1 text-xs text-red-600">{errors.order_date.message}</p>
        )}
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Amount ($) <span className="text-red-500">*</span>
        </label>
        <input
          type="number"
          step="0.01"
          min="0.01"
          {...register("order_amount", {
            required: "Amount is required",
            min: { value: 0.01, message: "Amount must be positive" },
          })}
          className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 ${
            errors.order_amount ? "border-red-500" : "border-gray-300"
          }`}
        />
        {errors.order_amount && (
          <p className="mt-1 text-xs text-red-600">{errors.order_amount.message}</p>
        )}
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Description <span className="text-red-500">*</span>
        </label>
        <textarea
          rows={3}
          {...register("order_description", {
            required: "Description is required",
            maxLength: { value: 500, message: "Max 500 characters" },
          })}
          className={`w-full rounded-md border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none ${
            errors.order_description ? "border-red-500" : "border-gray-300"
          }`}
        />
        {errors.order_description && (
          <p className="mt-1 text-xs text-red-600">{errors.order_description.message}</p>
        )}
      </div>

      <div className="flex justify-end gap-3 pt-2">
        <Button type="button" variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? "Saving…" : submitLabel}
        </Button>
      </div>
    </form>
  );
}
