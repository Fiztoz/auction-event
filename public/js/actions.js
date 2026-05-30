import { api } from "./api.js";
import { state, clearMessages, resetAuthForm } from "./store.js";

const submit = async (path, payload, opts = {}) => {
  state.submitting = true;
  clearMessages();
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

// ── session ─────────────────────────────────────────────────────────

export const refreshMe = async () => {
  try {
    const { user } = await api("/api/me");
    state.user = user;
  } catch (_) {
    state.user = null;
  } finally {
    state.loading = false;
  }
};

export const signout = async () => {
  await api("/api/signout", { method: "POST" });
  state.user = null;
  state.view = "dashboard";
  state.authMode = "login";
  resetAuthForm();
};

// ── auth ────────────────────────────────────────────────────────────

export const signup = () => submit("/api/signup", {
  email: state.form.email, password: state.form.password, name: state.form.name
});

export const login = () => submit("/api/login", {
  email: state.form.email, password: state.form.password
});

export const switchToLogin  = () => { state.authMode = "login";  clearMessages(); };
export const switchToSignup = () => { state.authMode = "signup"; clearMessages(); };
export const switchToForgot = () => {
  state.authMode = "password_forgot";
  clearMessages();
  state.form.forgot_email = state.form.email;
};
export const switchToReset = () => { state.authMode = "password_reset"; clearMessages(); };

// ── password reset ──────────────────────────────────────────────────

export const requestPasswordReset = async () => {
  state.submitting = true;
  clearMessages();
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

export const resetPassword = async () => {
  state.submitting = true;
  clearMessages();
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

// ── onboarding wizard ───────────────────────────────────────────────

export const verifyEmail = () => submit("/api/onboarding/verify-email", {
  token: state.form.token
});

export const resendToken = async () => {
  state.resending = true;
  clearMessages();
  try {
    await api("/api/onboarding/resend-token", { method: "POST" });
    state.info = "A new code has been issued — check the server logs.";
  } catch (e) {
    state.error = e.message;
  } finally {
    state.resending = false;
  }
};

export const submitCreditScore = () => submit("/api/onboarding/credit-score", {
  income:        Number(state.form.income),
  employment:    state.form.employment,
  debt:          Number(state.form.debt),
  history_years: Number(state.form.history_years)
});

// ── profile ─────────────────────────────────────────────────────────

export const openEdit = () => {
  state.view = "edit";
  clearMessages();
  state.form.edit_name = state.user.name;
  state.form.edit_email = state.user.email;
  state.form.edit_current_password = "";
  state.form.edit_new_password = "";
};

export const cancelEdit = () => {
  state.view = "dashboard";
  clearMessages();
};

export const saveProfile = () => {
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
