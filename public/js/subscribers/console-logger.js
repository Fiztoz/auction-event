import { on } from "../events.js";

export const install = () => {
  on(({ name, payload, at }) => {
    const ts = at.toISOString().slice(11, 19);
    console.log(`[basic4 event ${ts}] ${name}`, payload);
  });
};
