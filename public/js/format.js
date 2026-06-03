// Shared display formatters. Prices travel as integer cents; render them as USD.
const usd = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });

export const currency = (cents) => usd.format((Number(cents) || 0) / 100);

// For a cents-accumulator input mask: keep only digits and read them as cents.
export const digitsToCents = (raw) => {
  const d = String(raw ?? "").replace(/\D/g, "").slice(0, 12);
  return d ? parseInt(d, 10) : 0;
};
