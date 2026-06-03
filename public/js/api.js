export const STEPS = ["signup", "verify_email", "credit_scoring", "done"];

export const api = async (path, opts = {}) => {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw Object.assign(new Error(data.error || "request failed"), { field: data.field });
  }
  return data;
};

// Multipart upload — let the browser set the Content-Type boundary, so we do
// NOT spread the JSON headers from `api`. Same error shape as `api`.
export const apiUpload = async (path, formData) => {
  const res = await fetch(path, {
    method: "POST",
    credentials: "same-origin",
    body: formData
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw Object.assign(new Error(data.error || "upload failed"), { field: data.field });
  }
  return data;
};
