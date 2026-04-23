import type { Outlet, Product, Transaction } from "./types";

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "/holefoods/api";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: {
      "Content-Type": "application/json",
    },
    ...init,
  });

  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }

  if (res.status === 204) {
    return undefined as T;
  }

  return (await res.json()) as T;
}

export function listProducts(): Promise<Product[]> {
  return request<Product[]>("/products");
}

export function createProduct(payload: Product): Promise<Product> {
  return request<Product>("/products", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function getProduct(sku: string): Promise<Product> {
  return request<Product>(`/products/${encodeURIComponent(sku)}`);
}

export function updateProduct(sku: string, payload: Product): Promise<Product> {
  return request<Product>(`/products/${encodeURIComponent(sku)}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function deleteProduct(sku: string): Promise<void> {
  return request<void>(`/products/${encodeURIComponent(sku)}`, {
    method: "DELETE",
  });
}

export function getSpec(): Promise<Record<string, unknown>> {
  return request<Record<string, unknown>>("/_spec");
}

export function listOutlets(): Promise<Outlet[]> {
  return request<Outlet[]>("/outlets");
}

type TransactionsParams = {
  startDate?: string;
  endDate?: string;
  outletId?: number;
  productSku?: string;
};

export function listTransactions(params: TransactionsParams): Promise<Transaction[]> {
  const query = new URLSearchParams();
  if (params.startDate) query.set("startDate", params.startDate);
  if (params.endDate) query.set("endDate", params.endDate);
  if (params.outletId) query.set("outletId", params.outletId.toString());
  if (params.productSku) query.set("productSku", params.productSku);
  const suffix = query.toString() ? `?${query.toString()}` : "";
  return request<Transaction[]>(`/transactions${suffix}`);
}
