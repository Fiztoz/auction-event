import { state } from "../store.js";
import { saveProfile, cancelEdit } from "../actions.js";

export const EditProfileScreen = {
  setup() {
    return { state, saveProfile, cancelEdit };
  },
  template: `
    <div class="card">
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
  `
};
