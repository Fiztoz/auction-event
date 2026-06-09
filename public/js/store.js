const { reactive } = Vue;

const emptyForm = () => ({
  email: "", password: "", name: "",
  token: "",
  income: "", employment: "", debt: "", history_years: "",
  ship_line1: "", ship_line2: "", ship_city: "", ship_region: "", ship_postal_code: "", ship_country: "US",
  edit_name: "", edit_email: "", edit_current_password: "", edit_new_password: "",
  forgot_email: "",
  reset_token: "", reset_new_password: "",
  product_title: "", product_description: "", product_category: "",
  product_starting_price: "", product_duration: "", product_images: []
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
  myAuctions: [],
  editingProductId: null,
  imageUploading: false,
  // ── notifications ───────────────────────────────────────────
  notifications: [],
  unreadCount: 0,
  notificationPanelOpen: false,
  // ── admin: pending products ─────────────────────────────────
  pendingProducts: [],
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
