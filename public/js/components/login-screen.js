import { state } from "../store.js";
import { login, switchToSignup, switchToForgot } from "../actions.js";

export const LoginScreen = {
  setup() {
    return { state, login, switchToSignup, switchToForgot };
  },
  template: `
    <div class="card">
      <h1>Welcome back</h1>
      <p class="subtitle">Sign in to continue.</p>
      <form @submit.prevent="login">
        <label>Email</label>
        <input type="email" v-model="state.form.email" required>
        <label>Password</label>
        <input type="password" v-model="state.form.password" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <div v-if="state.info" class="info">{{ state.info }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Signing in…' : 'Sign in' }}</button>
      </form>
      <p class="auth-toggle">
        <a href="#" @click.prevent="switchToForgot">Forgot password?</a>
      </p>
      <p class="auth-toggle">
        Don't have an account?
        <a href="#" @click.prevent="switchToSignup">Sign up</a>
      </p>
      <p class="auth-toggle">
        <a href="/browse">Browse auctions →</a>
      </p>
    </div>
  `
};
