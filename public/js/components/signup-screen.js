import { state } from "../store.js";
import { signup, switchToLogin } from "../actions.js";

export const SignupScreen = {
  setup() {
    return { state, signup, switchToLogin };
  },
  template: `
    <div class="card">
      <h1>Create your account</h1>
      <p class="subtitle">Step 1 of 4 — Basic info</p>
      <div class="steps">
        <div class="dot active"></div>
        <div class="dot"></div>
        <div class="dot"></div>
        <div class="dot"></div>
      </div>
      <form @submit.prevent="signup">
        <label>Name</label>
        <input type="text" v-model="state.form.name" required>
        <label>Email</label>
        <input type="email" v-model="state.form.email" required>
        <label>Password</label>
        <input type="password" v-model="state.form.password" minlength="8" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Creating…' : 'Continue' }}</button>
      </form>
      <p class="auth-toggle">
        Already have an account?
        <a href="#" @click.prevent="switchToLogin">Sign in</a>
      </p>
    </div>
  `
};
