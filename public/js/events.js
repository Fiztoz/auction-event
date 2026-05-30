const listeners = new Set();

export const on = (fn) => {
  listeners.add(fn);
  return () => listeners.delete(fn);
};

export const emit = (name, payload = {}) => {
  const event = { name, payload, at: new Date() };
  listeners.forEach((fn) => fn(event));
};
