import { state } from "../store.js";
import { submitCreditScore } from "../actions.js";

export const CreditScoringScreen = {
  setup() {
    return { state, submitCreditScore };
  },
  template: `
    <div class="card">
      <h1>Become a seller</h1>
      <p class="subtitle">A few details so we can score your seller application.</p>
      <form @submit.prevent="submitCreditScore">
        <label>Annual income (USD)</label>
        <input type="number" min="0" step="1" v-model="state.form.income" required>
        <label>Employment status</label>
        <select v-model="state.form.employment" required>
          <option value="" disabled>Select status…</option>
          <option value="employed">Employed</option>
          <option value="self_employed">Self-employed</option>
          <option value="student">Student</option>
          <option value="unemployed">Unemployed</option>
        </select>
        <label>Existing debt (USD)</label>
        <input type="number" min="0" step="1" v-model="state.form.debt" required>
        <label>Years of credit history</label>
        <input type="number" min="0" step="1" v-model="state.form.history_years" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Scoring…' : 'Finish' }}</button>
      </form>
    </div>
  `
};
