import { state } from "../store.js";
import { verifyEmail, resendToken } from "../actions.js";

export const VerifyEmailScreen = {
  setup() {
    return { state, verifyEmail, resendToken };
  },
  template: `
    <div class="card">
      <h1>Verify your email</h1>
      <p class="subtitle">Step 2 of 3 — We sent a 6-digit code to {{ state.user.email }}. Check the server logs for the code.</p>
      <div class="steps">
        <div class="dot active"></div>
        <div class="dot active"></div>
        <div class="dot"></div>
      </div>
      <form @submit.prevent="verifyEmail">
        <label>Verification code</label>
        <input type="text" inputmode="numeric" pattern="[0-9]{6}" maxlength="6"
               v-model="state.form.token" placeholder="123456" required>
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <div v-if="state.info" class="info">{{ state.info }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Verifying…' : 'Verify' }}</button>
        <p class="resend">
          Didn't get the code?
          <a href="#" @click.prevent="resendToken" :class="{ disabled: state.resending }">
            {{ state.resending ? 'Sending…' : 'Resend' }}
          </a>
        </p>
      </form>
    </div>
  `
};
