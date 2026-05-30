import { state } from "../store.js";
import { openEdit, signout } from "../actions.js";

export const DashboardScreen = {
  setup() {
    return { state, openEdit, signout };
  },
  template: `
    <div class="card success">
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
