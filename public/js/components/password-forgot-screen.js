import { state } from "../store.js";
import { requestPasswordReset, switchToReset, switchToLogin } from "../actions.js";

export const PasswordForgotScreen = {
  setup() {
    return { state, requestPasswordReset, switchToReset, switchToLogin };
  },
  template: `
    <div class="card">
      <h1>Reset your password</h1>
      <p class="subtitle">Enter your email and we'll issue a reset token.</p>
      <form @submit.prevent="requestPasswordReset">
        <label>Email</label>
        <input type="email" v-model="state.form.forgot_email" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Sending…' : 'Send reset token' }}</button>
      </form>
      <p class="auth-toggle">
        <a href="#" @click.prevent="switchToReset">I already have a token</a>
      </p>
      <p class="auth-toggle">
        <a href="#" @click.prevent="switchToLogin">Back to sign in</a>
      </p>
    </div>
  `
};
