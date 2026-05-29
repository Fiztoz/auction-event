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
      form: {
        email: "", password: "", name: "",
        token: "",
        income: "", employment: "", debt: "", history_years: ""
      }
    });

    const step = computed(() => state.user?.step || "signup");
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

    const submit = async (path, payload) => {
      state.submitting = true;
      state.error = "";
      state.info = "";
      try {
        const { user } = await api(path, { method: "POST", body: payload });
        state.user = user;
      } catch (e) {
        state.error = e.message;
      } finally {
        state.submitting = false;
      }
    };

    const signup = () => submit("/api/signup", {
      email: state.form.email, password: state.form.password, name: state.form.name
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

    const signout = async () => {
      await api("/api/signout", { method: "POST" });
      state.user = null;
      state.form.email = state.form.password = state.form.token = "";
    };

    onMounted(refreshMe);

    return { state, step, stepIndex, signup, verifyEmail, resendToken, submitCreditScore, signout };
  },

  template: `
    <div class="card" v-if="state.loading">Loading…</div>

    <div class="card" v-else-if="step === 'signup'">
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

    <div class="card success" v-else>
      <div class="check">✓</div>
      <h1>You're all set, {{ state.user.name }}!</h1>
      <p class="subtitle">Welcome to Basic4. Your application has been reviewed.</p>
      <p class="score" v-if="state.user.credit_score">
        Your credit score: <strong>{{ state.user.credit_score.score }}</strong>
      </p>
      <button @click="signout">Sign out</button>
    </div>
  `
};

createApp(App).mount("#app");
