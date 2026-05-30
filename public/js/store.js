const { reactive } = Vue;

const emptyForm = () => ({
  email: "", password: "", name: "",
  token: "",
  income: "", employment: "", debt: "", history_years: "",
  edit_name: "", edit_email: "", edit_current_password: "", edit_new_password: "",
  forgot_email: "",
  reset_token: "", reset_new_password: ""
});

export const state = reactive({
  loading: true,
  submitting: false,
  resending: false,
  error: "",
  info: "",
  user: null,
  authMode: "signup",
  view: "dashboard",
  form: emptyForm()
});

export const clearMessages = () => {
  state.error = "";
  state.info = "";
};

export const resetAuthForm = () => {
  state.form.email = "";
  state.form.password = "";
  state.form.token = "";
};
