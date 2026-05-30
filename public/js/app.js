import { state } from "./store.js";
import { refreshMe } from "./actions.js";
import { install as installConsoleLogger } from "./subscribers/console-logger.js";
import { SignupScreen } from "./components/signup-screen.js";
import { LoginScreen } from "./components/login-screen.js";
import { PasswordForgotScreen } from "./components/password-forgot-screen.js";
import { PasswordResetScreen } from "./components/password-reset-screen.js";
import { VerifyEmailScreen } from "./components/verify-email-screen.js";
import { CreditScoringScreen } from "./components/credit-scoring-screen.js";
import { EditProfileScreen } from "./components/edit-profile-screen.js";
import { DashboardScreen } from "./components/dashboard-screen.js";

const { createApp, computed, onMounted } = Vue;

const App = {
  components: {
    SignupScreen, LoginScreen, PasswordForgotScreen, PasswordResetScreen,
    VerifyEmailScreen, CreditScoringScreen, EditProfileScreen, DashboardScreen
  },

  setup() {
    const step = computed(() => state.user?.step || state.authMode);

    onMounted(() => {
      const params = new URLSearchParams(window.location.search);
      const resetToken = params.get("reset");
      if (resetToken) {
        state.form.reset_token = resetToken;
        state.authMode = "password_reset";
      }
      refreshMe();
    });

    return { state, step };
  },

  template: `
    <div class="card" v-if="state.loading">Loading…</div>
    <signup-screen          v-else-if="!state.user && state.authMode === 'signup'" />
    <login-screen           v-else-if="!state.user && state.authMode === 'login'" />
    <password-forgot-screen v-else-if="!state.user && state.authMode === 'password_forgot'" />
    <password-reset-screen  v-else-if="!state.user && state.authMode === 'password_reset'" />
    <verify-email-screen    v-else-if="step === 'verify_email'" />
    <credit-scoring-screen  v-else-if="step === 'credit_scoring'" />
    <edit-profile-screen    v-else-if="step === 'done' && state.view === 'edit'" />
    <dashboard-screen       v-else-if="step === 'done'" />
  `
};

installConsoleLogger();

createApp(App).mount("#app");
