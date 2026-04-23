export type Product = {
  SKU: string;
  Name: string;
  Category?: string;
  Price?: number;
};

export type Outlet = {
  OutletId: number;
  City: string;
  Country?: string;
  Type?: string;
};

export type Transaction = {
  TransactionId: number;
  DateOfSale: string | number;
  Actual?: boolean;
  AmountOfSale?: number | string;
  UnitsSold?: number | string;
  Discount?: number | string;
  ProductSKU: string;
  ProductName?: string;
  OutletId?: number;
  OutletCity?: string;
};

export type ApiError = {
  status: number;
  message: string;
};
