import { state } from "../store.js";
import { openEdit, signout, openSell, openEditAuction, loadMyAuctions } from "../actions.js";

const { onMounted } = Vue;

export const DashboardScreen = {
  setup() {
    onMounted(loadMyAuctions);
    const dollars = (cents) => (cents / 100).toFixed(2);
    return { state, openEdit, signout, openSell, openEditAuction, dollars };
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

      <div class="menu">
        <button @click="openSell">+ Sell a product at auction</button>
        <a class="link-button" href="/browse">Browse all auctions →</a>
      </div>

      <div class="auctions" v-if="state.myAuctions.length">
        <h2>My auctions ({{ state.myAuctions.length }})</h2>
        <div class="auction-item" v-for="a in state.myAuctions" :key="a.id">
          <img class="auction-thumb" v-if="a.images && a.images.length" :src="a.images[0]" alt="">
          <div class="auction-text">
            <span class="auction-title">{{ a.title }}</span>
            <span class="auction-meta">\${{ dollars(a.starting_price_cents) }} · {{ a.status }}</span>
          </div>
          <button type="button" class="link-button auction-edit" @click="openEditAuction(a)">Edit</button>
        </div>
      </div>

      <button type="button" class="link-button" @click="openEdit">Edit profile</button>
      <button type="button" class="link-button" @click="signout">Sign out</button>
    </div>
  `
};
