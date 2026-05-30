import { state } from "../store.js";
import { resetPassword, switchToLogin } from "../actions.js";

export const PasswordResetScreen = {
  setup() {
    return { state, resetPassword, switchToLogin };
  },
  template: `
    <div class="card">
      <h1>Set a new password</h1>
      <p class="subtitle">Paste the reset token from the server logs and choose a new password.</p>
      <form @submit.prevent="resetPassword">
        <label>Reset token</label>
        <input type="text" v-model="state.form.reset_token" autocomplete="off" required>
        <label>New password</label>
        <input type="password" v-model="state.form.reset_new_password" minlength="8" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <div v-if="state.info" class="info">{{ state.info }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Updating…' : 'Update password' }}</button>
      </form>
      <p class="auth-toggle">
        <a href="#" @click.prevent="switchToLogin">Back to sign in</a>
      </p>
    </div>
  `
};
