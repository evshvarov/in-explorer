import { useEffect, useMemo, useState } from "react";
import {
  createProduct,
  deleteProduct,
  getSpec,
  listProducts,
  listTransactions,
  listOutlets,
  updateProduct,
} from "./api";
import type { Outlet, Product, Transaction } from "./types";

type FormState = {
  SKU: string;
  Name: string;
  Category: string;
  Price: string;
};

const emptyForm: FormState = {
  SKU: "",
  Name: "",
  Category: "",
  Price: "",
};

export default function App() {
  const [view, setView] = useState<"products" | "sales" | "sales-year">(
    "products",
  );
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [createForm, setCreateForm] = useState<FormState>(emptyForm);
  const [editForm, setEditForm] = useState<FormState>(emptyForm);
  const [editingSku, setEditingSku] = useState<string | null>(null);
  const [specOpen, setSpecOpen] = useState(false);
  const [specJson, setSpecJson] = useState<string>("");
  const [outlets, setOutlets] = useState<Outlet[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [transactionsLoading, setTransactionsLoading] = useState(false);
  const [filters, setFilters] = useState({
    startDate: "",
    endDate: "",
    outletId: "",
    productSku: "",
  });
  const [productsList, setProductsList] = useState<Product[]>([]);
  const [salesSku, setSalesSku] = useState("");
  const [salesOutletId, setSalesOutletId] = useState("");
  const [salesTransactions, setSalesTransactions] = useState<Transaction[]>([]);
  const [salesYears, setSalesYears] = useState<number[]>([]);
  const [salesSelectedYears, setSalesSelectedYears] = useState<number[]>([]);
  const [salesLoading, setSalesLoading] = useState(false);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return products;
    return products.filter((item) => {
      return (
        item.SKU.toLowerCase().includes(q) ||
        item.Name.toLowerCase().includes(q) ||
        (item.Category || "").toLowerCase().includes(q)
      );
    });
  }, [products, query]);

  useEffect(() => {
    void reloadProducts();
  }, []);

  useEffect(() => {
    if (view !== "sales") return;
    if (outlets.length === 0) {
      void loadOutlets();
    }
    void loadTransactions();
  }, [view]);

  useEffect(() => {
    if (view !== "sales-year") return;
    if (outlets.length === 0) {
      void loadOutlets();
    }
    if (productsList.length === 0) {
      void loadProductsList();
    }
  }, [view]);

  async function reloadProducts() {
    setLoading(true);
    setError(null);
    try {
      const data = await listProducts();
      setProducts(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load products.");
    } finally {
      setLoading(false);
    }
  }

  async function loadProductsList() {
    try {
      const data = await listProducts();
      setProductsList(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load products.");
    }
  }

  async function loadOutlets() {
    try {
      const data = await listOutlets();
      setOutlets(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load outlets.");
    }
  }

  async function loadTransactions() {
    setTransactionsLoading(true);
    setError(null);
    try {
      const data = await listTransactions({
        startDate: filters.startDate || undefined,
        endDate: filters.endDate || undefined,
        outletId: filters.outletId ? Number(filters.outletId) : undefined,
        productSku: filters.productSku.trim() || undefined,
      });
      setTransactions(data);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Unable to load transactions.",
      );
    } finally {
      setTransactionsLoading(false);
    }
  }

  function getYearFromDateValue(value: string | number | undefined) {
    if (value === undefined || value === null) return null;
    const raw = String(value).trim();
    if (!raw) return null;
    if (/^\d+$/.test(raw)) {
      const days = Number(raw);
      if (Number.isNaN(days)) return null;
      const base = new Date(Date.UTC(1840, 11, 31));
      const date = new Date(base.getTime() + days * 86400000);
      return date.getUTCFullYear();
    }
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) return null;
    return date.getFullYear();
  }

  function getMonthFromDateValue(value: string | number | undefined) {
    if (value === undefined || value === null) return null;
    const raw = String(value).trim();
    if (!raw) return null;
    if (/^\d+$/.test(raw)) {
      const days = Number(raw);
      if (Number.isNaN(days)) return null;
      const base = new Date(Date.UTC(1840, 11, 31));
      const date = new Date(base.getTime() + days * 86400000);
      return date.getUTCMonth();
    }
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) return null;
    return date.getMonth();
  }

  async function loadSalesByYear() {
    if (!salesSku.trim()) {
      setError("Select a SKU to view sales by year.");
      return;
    }
    setSalesLoading(true);
    setError(null);
    try {
      const data = await listTransactions({
        outletId: salesOutletId ? Number(salesOutletId) : undefined,
        productSku: salesSku.trim(),
      });
      setSalesTransactions(data);
      const years = Array.from(
        new Set(
          data
            .map((item) => getYearFromDateValue(item.DateOfSale))
            .filter((year): year is number => year !== null),
        ),
      ).sort((a, b) => a - b);
      setSalesYears(years);
      if (salesSelectedYears.length === 0) {
        setSalesSelectedYears(years);
      }
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Unable to load sales data.",
      );
    } finally {
      setSalesLoading(false);
    }
  }

  function parsePrice(value: string) {
    if (value.trim() === "") return undefined;
    const parsed = Number(value);
    return Number.isNaN(parsed) ? undefined : parsed;
  }

  async function handleCreate(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    const payload: Product = {
      SKU: createForm.SKU.trim(),
      Name: createForm.Name.trim(),
      Category: createForm.Category.trim() || undefined,
      Price: parsePrice(createForm.Price),
    };

    if (!payload.SKU || !payload.Name) {
      setError("SKU and Name are required.");
      return;
    }

    try {
      const created = await createProduct(payload);
      setProducts((prev) => [created, ...prev]);
      setCreateForm(emptyForm);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to create product.");
    }
  }

  function startEdit(product: Product) {
    setEditingSku(product.SKU);
    setEditForm({
      SKU: product.SKU,
      Name: product.Name,
      Category: product.Category || "",
      Price: product.Price?.toString() || "",
    });
  }

  function cancelEdit() {
    setEditingSku(null);
    setEditForm(emptyForm);
  }

  async function handleUpdate(event: React.FormEvent) {
    event.preventDefault();
    if (!editingSku) return;
    setError(null);
    const payload: Product = {
      SKU: editForm.SKU.trim(),
      Name: editForm.Name.trim(),
      Category: editForm.Category.trim() || undefined,
      Price: parsePrice(editForm.Price),
    };

    if (!payload.Name) {
      setError("Name is required.");
      return;
    }

    try {
      const updated = await updateProduct(editingSku, payload);
      setProducts((prev) =>
        prev.map((item) => (item.SKU === editingSku ? updated : item)),
      );
      cancelEdit();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update product.");
    }
  }

  async function handleDelete(sku: string) {
    setError(null);
    try {
      await deleteProduct(sku);
      setProducts((prev) => prev.filter((item) => item.SKU !== sku));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to delete product.");
    }
  }

  async function handleLoadSpec() {
    setError(null);
    try {
      const spec = await getSpec();
      setSpecJson(JSON.stringify(spec, null, 2));
      setSpecOpen(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to fetch spec.");
    }
  }

  const totalSales = transactions.reduce(
    (sum, item) => sum + (Number(item.AmountOfSale) || 0),
    0,
  );
  const totalUnits = transactions.reduce(
    (sum, item) => sum + (Number(item.UnitsSold) || 0),
    0,
  );
  const uniqueSkus = new Set(transactions.map((item) => item.ProductSKU)).size;

  const heroStats =
    view === "sales"
      ? [
          { label: "Total Sales", value: totalSales },
          { label: "Units Sold", value: totalUnits },
          { label: "Filtered SKU Count", value: uniqueSkus },
        ]
      : view === "sales-year"
      ? [
          { label: "Selected SKU", value: salesSku || "None" },
          { label: "Years Loaded", value: salesYears.length },
          { label: "Transactions", value: salesTransactions.length },
        ]
      : [
          { label: "Inventory Items", value: products.length },
          { label: "Status", value: loading ? "Syncing" : "Live" },
          { label: "Endpoint", value: "/holefoods/api" },
        ];

  return (
    <div className="app">
      <header className="hero">
        <div>
          <p className="eyebrow">HoleFoods API Console</p>
          <h1>
            {view === "sales"
              ? "Sales intelligence in one focused dashboard."
              : "Product control with live Swagger wiring."}
          </h1>
          <p className="subhead">
            {view === "sales"
              ? "Filter by outlet and date to track revenue by SKU."
              : "Manage catalog items, validate new SKUs, and export the API spec in one focused workspace."}
          </p>
          <div className="tabs">
            <button
              className={view === "products" ? "tab active" : "tab"}
              onClick={() => setView("products")}
            >
              Products
            </button>
            <button
              className={view === "sales" ? "tab active" : "tab"}
              onClick={() => setView("sales")}
            >
              Sales
            </button>
            <button
              className={view === "sales-year" ? "tab active" : "tab"}
              onClick={() => setView("sales-year")}
            >
              Sales by Year
            </button>
          </div>
          <div className="hero-actions">
            <button className="primary" onClick={handleLoadSpec}>
              View Spec
            </button>
            {view === "products" ? (
              <button className="ghost" onClick={reloadProducts}>
                Refresh Products
              </button>
            ) : view === "sales" ? (
              <button className="ghost" onClick={loadTransactions}>
                Refresh Transactions
              </button>
            ) : (
              <button className="ghost" onClick={loadSalesByYear}>
                Refresh Sales
              </button>
            )}
          </div>
        </div>
        <div className="hero-card">
          {heroStats.map((stat) => (
            <div className="stat" key={stat.label}>
              <span>{stat.label}</span>
              <strong>
                {typeof stat.value === "number"
                  ? stat.label.includes("Sales")
                    ? `$${stat.value.toFixed(2)}`
                    : stat.value
                  : stat.value}
              </strong>
            </div>
          ))}
        </div>
      </header>

      {view === "products" ? (
        <main className="grid">
          <section className="panel">
            <div className="panel-header">
              <div>
                <h2>Create Product</h2>
                <p>Send a POST to /products with a curated payload.</p>
              </div>
            </div>
            <form className="form" onSubmit={handleCreate}>
              <label>
                SKU
                <input
                  value={createForm.SKU}
                  onChange={(event) =>
                    setCreateForm({ ...createForm, SKU: event.target.value })
                  }
                  placeholder="SKU-101"
                />
              </label>
              <label>
                Name
                <input
                  value={createForm.Name}
                  onChange={(event) =>
                    setCreateForm({ ...createForm, Name: event.target.value })
                  }
                  placeholder="Bagels (dozen)"
                />
              </label>
              <label>
                Category
                <input
                  value={createForm.Category}
                  onChange={(event) =>
                    setCreateForm({
                      ...createForm,
                      Category: event.target.value,
                    })
                  }
                  placeholder="Snack"
                />
              </label>
              <label>
                Price
                <input
                  value={createForm.Price}
                  onChange={(event) =>
                    setCreateForm({ ...createForm, Price: event.target.value })
                  }
                  placeholder="2.95"
                />
              </label>
              <button className="primary" type="submit">
                Create Product
              </button>
            </form>
          </section>

          <section className="panel">
            <div className="panel-header">
              <div>
                <h2>Catalog</h2>
                <p>Search and edit live inventory in place.</p>
              </div>
              <input
                className="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Search SKU, name, category"
              />
            </div>

            {loading ? (
              <div className="empty">Loading products...</div>
            ) : filtered.length === 0 ? (
              <div className="empty">No products match this query.</div>
            ) : (
              <div className="cards">
                {filtered.map((product) => (
                  <article className="card" key={product.SKU}>
                    <div className="card-top">
                      <div>
                        <p className="sku">{product.SKU}</p>
                        <h3>{product.Name}</h3>
                        <p className="meta">
                          {product.Category || "Uncategorized"}
                        </p>
                      </div>
                      <span className="price">
                        {product.Price !== undefined
                          ? `$${product.Price.toFixed(2)}`
                          : "--"}
                      </span>
                    </div>
                    <div className="card-actions">
                      <button
                        className="ghost"
                        onClick={() => startEdit(product)}
                      >
                        Edit
                      </button>
                      <button
                        className="danger"
                        onClick={() => handleDelete(product.SKU)}
                      >
                        Delete
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </section>
        </main>
      ) : view === "sales" ? (
        <main className="sales-grid">
          <section className="panel filters">
            <div className="panel-header">
              <div>
                <h2>Transaction Filters</h2>
                <p>Filter by date range, outlet, and SKU to focus sales.</p>
              </div>
            </div>
            <div className="filters-grid">
              <label>
                Start Date
                <input
                  type="date"
                  value={filters.startDate}
                  onChange={(event) =>
                    setFilters({ ...filters, startDate: event.target.value })
                  }
                />
              </label>
              <label>
                End Date
                <input
                  type="date"
                  value={filters.endDate}
                  onChange={(event) =>
                    setFilters({ ...filters, endDate: event.target.value })
                  }
                />
              </label>
              <label>
                Outlet
                <select
                  value={filters.outletId}
                  onChange={(event) =>
                    setFilters({ ...filters, outletId: event.target.value })
                  }
                >
                  <option value="">All outlets</option>
                  {outlets.map((outlet) => (
                    <option key={outlet.OutletId} value={outlet.OutletId}>
                      {outlet.City}
                      {outlet.Country ? `, ${outlet.Country}` : ""}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Product SKU
                <input
                  value={filters.productSku}
                  onChange={(event) =>
                    setFilters({ ...filters, productSku: event.target.value })
                  }
                  placeholder="SKU-101"
                />
              </label>
              <button className="primary" onClick={loadTransactions}>
                Apply Filters
              </button>
            </div>
          </section>

          <section className="panel">
            <div className="panel-header">
              <div>
                <h2>Transactions</h2>
                <p>Every matching sale across outlets and SKUs.</p>
              </div>
            </div>
            {transactionsLoading ? (
              <div className="empty">Loading transactions...</div>
            ) : transactions.length > 0 ? (
              <div className="table">
                <div className="table-head">
                  <span>Date</span>
                  <span>SKU</span>
                  <span>Product</span>
                  <span>Outlet</span>
                  <span>Units</span>
                  <span>Amount</span>
                </div>
                {transactions.map((item) => (
                  <div className="table-row" key={item.TransactionId}>
                    <span>{item.DateOfSale}</span>
                    <span className="sku">{item.ProductSKU}</span>
                    <span>{item.ProductName || "Unnamed"}</span>
                    <span>{item.OutletCity || "Unknown"}</span>
                    <span>{Number(item.UnitsSold) || 0}</span>
                    <span>
                      $
                      {(Number(item.AmountOfSale) || 0).toFixed(2)}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <div className="empty">No transactions for this selection.</div>
            )}
          </section>
        </main>
      ) : (
        <main className="sales-grid">
          <section className="panel filters">
            <div className="panel-header">
              <div>
                <h2>SKU Sales Filters</h2>
                <p>Pick a SKU, outlet, and years to chart totals.</p>
              </div>
            </div>
            <div className="filters-grid">
              <label>
                Product SKU
                <select
                  value={salesSku}
                  onChange={(event) => setSalesSku(event.target.value)}
                >
                  <option value="">Select SKU</option>
                  {productsList.map((product) => (
                    <option key={product.SKU} value={product.SKU}>
                      {product.SKU} - {product.Name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Outlet
                <select
                  value={salesOutletId}
                  onChange={(event) => setSalesOutletId(event.target.value)}
                >
                  <option value="">All outlets</option>
                  {outlets.map((outlet) => (
                    <option key={outlet.OutletId} value={outlet.OutletId}>
                      {outlet.City}
                      {outlet.Country ? `, ${outlet.Country}` : ""}
                    </option>
                  ))}
                </select>
              </label>
              <div className="filters-actions">
                <button className="primary" onClick={loadSalesByYear}>
                  Load Sales
                </button>
              </div>
            </div>
            <div className="year-filter">
              {salesYears.length === 0 ? (
                <p className="empty">Select a SKU to load available years.</p>
              ) : (
                salesYears.map((year) => (
                  <label key={year} className="year-pill">
                    <input
                      type="checkbox"
                      checked={salesSelectedYears.includes(year)}
                      onChange={(event) => {
                        if (event.target.checked) {
                          setSalesSelectedYears((prev) => [...prev, year]);
                        } else {
                          setSalesSelectedYears((prev) =>
                            prev.filter((value) => value !== year),
                          );
                        }
                      }}
                    />
                    <span>{year}</span>
                  </label>
                ))
              )}
            </div>
          </section>
          <section className="panel">
            <div className="panel-header">
              <div>
                <h2>Sales by Year</h2>
                <p>Totals for the selected SKU across chosen years.</p>
              </div>
            </div>
            {salesLoading ? (
              <div className="empty">Loading sales by year...</div>
            ) : salesTransactions.length === 0 ? (
              <div className="empty">No transactions loaded yet.</div>
            ) : (() => {
                const totals = salesTransactions.reduce((acc, item) => {
                  const year = getYearFromDateValue(item.DateOfSale);
                  if (year === null) return acc;
                  if (!salesSelectedYears.includes(year)) return acc;
                  const next = acc.get(year) || {
                    total: 0,
                    units: 0,
                    count: 0,
                  };
                  next.total += Number(item.AmountOfSale) || 0;
                  next.units += Number(item.UnitsSold) || 0;
                  next.count += 1;
                  acc.set(year, next);
                  return acc;
                }, new Map<number, { total: number; units: number; count: number }>());
                const rows = Array.from(totals.entries()).sort(
                  (a, b) => b[0] - a[0],
                );
                const maxTotal = rows.reduce(
                  (max, [, data]) => Math.max(max, data.total),
                  0,
                );
                return rows.length === 0 ? (
                  <div className="empty">No data for the selected years.</div>
                ) : (
                  <div className="year-table">
                    {rows.map(([year, data]) => (
                      <div className="year-row" key={year}>
                        <div>
                          <p className="year-label">{year}</p>
                          <p className="year-meta">
                            {data.count} transactions · {data.units} units
                          </p>
                        </div>
                        <div className="year-bar">
                          <span
                            style={{
                              width: maxTotal
                                ? `${(data.total / maxTotal) * 100}%`
                                : "0%",
                            }}
                          />
                        </div>
                        <strong>${data.total.toFixed(2)}</strong>
                      </div>
                    ))}
                  </div>
                );
              })()}
          </section>
          <section className="panel">
            <div className="panel-header">
              <div>
                <h2>Monthly Sales</h2>
                <p>Distribution for the selected SKU across chosen years.</p>
              </div>
            </div>
            {salesLoading ? (
              <div className="empty">Loading monthly sales...</div>
            ) : salesTransactions.length === 0 ? (
              <div className="empty">No transactions loaded yet.</div>
            ) : (() => {
                const months = new Array(12)
                  .fill(0)
                  .map(() => ({ total: 0, units: 0 }));
                salesTransactions.forEach((item) => {
                  const year = getYearFromDateValue(item.DateOfSale);
                  if (year === null) return;
                  if (salesSelectedYears.length > 0) {
                    if (!salesSelectedYears.includes(year)) return;
                  }
                  const month = getMonthFromDateValue(item.DateOfSale);
                  if (month === null) return;
                  months[month].total += Number(item.AmountOfSale) || 0;
                  months[month].units += Number(item.UnitsSold) || 0;
                });
                const maxTotal = months.reduce(
                  (max, entry) => Math.max(max, entry.total),
                  0,
                );
                const labels = [
                  "Jan",
                  "Feb",
                  "Mar",
                  "Apr",
                  "May",
                  "Jun",
                  "Jul",
                  "Aug",
                  "Sep",
                  "Oct",
                  "Nov",
                  "Dec",
                ];
                return (
                  <div className="month-chart">
                    {months.map((entry, index) => (
                      <div className="month-bar" key={labels[index]}>
                        <div className="month-bar-inner">
                          <span
                            style={{
                              height: maxTotal
                                ? `${(entry.total / maxTotal) * 100}%`
                                : "0%",
                            }}
                          />
                        </div>
                        <p>{labels[index]}</p>
                        <small>
                          ${entry.total.toFixed(2)} · {entry.units} units
                        </small>
                      </div>
                    ))}
                  </div>
                );
              })()}
          </section>
        </main>
      )}

      <section className={`drawer ${editingSku ? "open" : ""}`}>
        <div className="drawer-content">
          <div className="drawer-header">
            <div>
              <h2>Edit Product</h2>
              <p>Update fields and push a PUT to /products/{`{sku}`}.</p>
            </div>
            <button className="ghost" onClick={cancelEdit}>
              Close
            </button>
          </div>
          <form className="form" onSubmit={handleUpdate}>
            <label>
              SKU
              <input value={editForm.SKU} disabled />
            </label>
            <label>
              Name
              <input
                value={editForm.Name}
                onChange={(event) =>
                  setEditForm({ ...editForm, Name: event.target.value })
                }
              />
            </label>
            <label>
              Category
              <input
                value={editForm.Category}
                onChange={(event) =>
                  setEditForm({ ...editForm, Category: event.target.value })
                }
              />
            </label>
            <label>
              Price
              <input
                value={editForm.Price}
                onChange={(event) =>
                  setEditForm({ ...editForm, Price: event.target.value })
                }
              />
            </label>
            <div className="drawer-actions">
              <button className="primary" type="submit">
                Save Changes
              </button>
              <button className="ghost" type="button" onClick={cancelEdit}>
                Cancel
              </button>
            </div>
          </form>
        </div>
      </section>

      <section className={`drawer ${specOpen ? "open" : ""}`}>
        <div className="drawer-content spec">
          <div className="drawer-header">
            <div>
              <h2>OpenAPI Spec</h2>
              <p>Fetched from /_spec for quick inspection.</p>
            </div>
            <button className="ghost" onClick={() => setSpecOpen(false)}>
              Close
            </button>
          </div>
          <pre>{specJson || "No spec loaded yet."}</pre>
        </div>
      </section>

      {error ? <div className="toast">{error}</div> : null}
    </div>
  );
}
