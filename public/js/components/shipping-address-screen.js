import { state } from "../store.js";
import { saveShippingAddress } from "../actions.js";

export const ShippingAddressScreen = {
  setup() {
    return { state, saveShippingAddress };
  },
  template: `
    <div class="card">
      <h1>Shipping address</h1>
      <p class="subtitle">Step 3 of 3 — Where should your orders ship?</p>
      <div class="steps">
        <div class="dot active"></div>
        <div class="dot active"></div>
        <div class="dot active"></div>
      </div>
      <form @submit.prevent="saveShippingAddress">
        <label>Address line 1</label>
        <input type="text" v-model="state.form.ship_line1" required>
        <label>Address line 2 (optional)</label>
        <input type="text" v-model="state.form.ship_line2">
        <label>City</label>
        <input type="text" v-model="state.form.ship_city" required>
        <label>State / region</label>
        <input type="text" v-model="state.form.ship_region" required>
        <label>ZIP / postal code</label>
        <input type="text" v-model="state.form.ship_postal_code" required>
        <label>Country</label>
        <input type="text" v-model="state.form.ship_country" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Saving…' : 'Finish' }}</button>
      </form>
    </div>
  `
};
