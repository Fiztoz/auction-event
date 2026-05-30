const { createApp, reactive, computed, onMounted } = Vue;

const api = async (path, opts = {}) => {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.error || "request failed"), { field: data.field });
  return data;
};

const STEPS = ["signup", "verify_email", "credit_scoring", "done"];

const App = {
  setup() {
    const state = reactive({
      loading: true,
      submitting: false,
      resending: false,
      error: "",
      info: "",
      user: null,
      authMode: "signup",
      view: "dashboard",
      form: {
        email: "", password: "", name: "",
        token: "",
        income: "", employment: "", debt: "", history_years: "",
        edit_name: "", edit_email: "", edit_current_password: "", edit_new_password: "",
        forgot_email: "",
        reset_token: "", reset_new_password: ""
      }
    });

    const step = computed(() => state.user?.step || state.authMode);
    const stepIndex = computed(() => STEPS.indexOf(step.value));

    const refreshMe = async () => {
      try {
        const { user } = await api("/api/me");
        state.user = user;
      } catch (_) {
        state.user = null;
      } finally {
        state.loading = false;
      }
    };

    const submit = async (path, payload, opts = {}) => {
      state.submitting = true;
      state.error = "";
      state.info = "";
      try {
        const { user } = await api(path, { method: opts.method || "POST", body: payload });
        state.user = user;
        if (opts.onSuccess) opts.onSuccess();
      } catch (e) {
        state.error = e.message;
      } finally {
        state.submitting = false;
      }
    };

    const signup = () => submit("/api/signup", {
      email: state.form.email, password: state.form.password, name: state.form.name
    });

    const login = () => submit("/api/login", {
      email: state.form.email, password: state.form.password
    });

    const verifyEmail = () => submit("/api/onboarding/verify-email", {
      token: state.form.token
    });

    const resendToken = async () => {
      state.resending = true;
      state.error = "";
      state.info = "";
      try {
        await api("/api/onboarding/resend-token", { method: "POST" });
        state.info = "A new code has been issued — check the server logs.";
      } catch (e) {
        state.error = e.message;
      } finally {
        state.resending = false;
      }
    };

    const submitCreditScore = () => submit("/api/onboarding/credit-score", {
      income:        Number(state.form.income),
      employment:    state.form.employment,
      debt:          Number(state.form.debt),
      history_years: Number(state.form.history_years)
    });

    const openEdit = () => {
      state.view = "edit";
      state.error = "";
      state.info = "";
      state.form.edit_name = state.user.name;
      state.form.edit_email = state.user.email;
      state.form.edit_current_password = "";
      state.form.edit_new_password = "";
    };

    const cancelEdit = () => {
      state.view = "dashboard";
      state.error = "";
      state.info = "";
    };

    const saveProfile = () => {
      const payload = {};
      if (state.form.edit_name && state.form.edit_name !== state.user.name) {
        payload.name = state.form.edit_name;
      }
      if (state.form.edit_email && state.form.edit_email !== state.user.email) {
        payload.email = state.form.edit_email;
      }
      if (state.form.edit_new_password) {
        payload.new_password = state.form.edit_new_password;
      }
      if (state.form.edit_current_password) {
        payload.current_password = state.form.edit_current_password;
      }
      return submit("/api/profile", payload, {
        method: "PATCH",
        onSuccess: () => {
          state.view = "dashboard";
          state.info = "Profile updated.";
        }
      });
    };

    const switchToLogin = () => {
      state.authMode = "login";
      state.error = ""; state.info = "";
    };
    const switchToSignup = () => {
      state.authMode = "signup";
      state.error = ""; state.info = "";
    };
    const switchToForgot = () => {
      state.authMode = "password_forgot";
      state.error = ""; state.info = "";
      state.form.forgot_email = state.form.email;
    };
    const switchToReset = () => {
      state.authMode = "password_reset";
      state.error = ""; state.info = "";
    };

    const requestPasswordReset = async () => {
      state.submitting = true;
      state.error = "";
      state.info = "";
      try {
        await api("/api/password/forgot", {
          method: "POST",
          body: { email: state.form.forgot_email }
        });
        state.authMode = "password_reset";
        state.info = "If an account exists for that email, a reset token has been issued. Check the server logs.";
      } catch (e) {
        state.error = e.message;
      } finally {
        state.submitting = false;
      }
    };

    const resetPassword = async () => {
      state.submitting = true;
      state.error = "";
      state.info = "";
      try {
        await api("/api/password/reset", {
          method: "POST",
          body: {
            token: state.form.reset_token,
            new_password: state.form.reset_new_password
          }
        });
        state.authMode = "login";
        state.info = "Password updated. You can sign in with your new password.";
        state.form.reset_token = "";
        state.form.reset_new_password = "";
      } catch (e) {
        state.error = e.message;
      } finally {
        state.submitting = false;
      }
    };

    const signout = async () => {
      await api("/api/signout", { method: "POST" });
      state.user = null;
      state.view = "dashboard";
      state.authMode = "login";
      state.form.email = state.form.password = state.form.token = "";
    };

    onMounted(() => {
      const params = new URLSearchParams(window.location.search);
      const resetToken = params.get("reset");
      if (resetToken) {
        state.form.reset_token = resetToken;
        state.authMode = "password_reset";
      }
      refreshMe();
    });

    return {
      state, step, stepIndex,
      signup, login, verifyEmail, resendToken, submitCreditScore,
      openEdit, cancelEdit, saveProfile,
      switchToLogin, switchToSignup, switchToForgot, switchToReset,
      requestPasswordReset, resetPassword,
      signout
    };
  },

  template: `
    <div class="card" v-if="state.loading">Loading…</div>

    <div class="card" v-else-if="!state.user && state.authMode === 'signup'">
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

    <div class="card" v-else-if="!state.user && state.authMode === 'login'">
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
    </div>

    <div class="card" v-else-if="!state.user && state.authMode === 'password_forgot'">
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

    <div class="card" v-else-if="!state.user && state.authMode === 'password_reset'">
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

    <div class="card" v-else-if="step === 'verify_email'">
      <h1>Verify your email</h1>
      <p class="subtitle">Step 2 of 4 — We sent a 6-digit code to {{ state.user.email }}. Check the server logs for the code.</p>
      <div class="steps">
        <div class="dot active"></div>
        <div class="dot active"></div>
        <div class="dot"></div>
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

    <div class="card" v-else-if="step === 'credit_scoring'">
      <h1>Credit profile</h1>
      <p class="subtitle">Step 3 of 4 — A few details so we can score your application.</p>
      <div class="steps">
        <div class="dot active"></div>
        <div class="dot active"></div>
        <div class="dot active"></div>
        <div class="dot"></div>
      </div>
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

    <div class="card" v-else-if="step === 'done' && state.view === 'edit'">
      <h1>Edit profile</h1>
      <p class="subtitle">Update your name, email, or password.</p>
      <form @submit.prevent="saveProfile">
        <label>Name</label>
        <input type="text" v-model="state.form.edit_name" required>
        <label>Email</label>
        <input type="email" v-model="state.form.edit_email" required>
        <label>New password (optional)</label>
        <input type="password" v-model="state.form.edit_new_password" placeholder="Leave blank to keep current">
        <label>Current password</label>
        <input type="password" v-model="state.form.edit_current_password"
               placeholder="Required to change email or password">
        <div v-if="state.error" class="error">{{ state.error }}</div>
        <button :disabled="state.submitting">{{ state.submitting ? 'Saving…' : 'Save changes' }}</button>
        <button type="button" class="link-button" @click="cancelEdit">Cancel</button>
      </form>
    </div>

    <div class="card success" v-else-if="step === 'done'">
      <div class="check">✓</div>
      <h1>Hi, {{ state.user.name }}</h1>
      <p class="subtitle">Welcome back to Basic4.</p>
      <div class="profile-row">
        <span class="profile-label">Name</span>
        <span class="profile-value">{{ state.user.name }}</span>
      </div>
      <div class="profile-row">
        <span class="profile-label">Email</span>
        <span class="profile-value">
          {{ state.user.email }}
          <span class="badge verified" v-if="state.user.email_verified">Verified</span>
        </span>
      </div>
      <p class="score" v-if="state.user.credit_score">
        Your credit score: <strong>{{ state.user.credit_score.score }}</strong>
      </p>
      <div v-if="state.info" class="info">{{ state.info }}</div>
      <button @click="openEdit">Edit profile</button>
      <button type="button" class="link-button" @click="signout">Sign out</button>
    </div>
  `
};

createApp(App).mount("#app");
