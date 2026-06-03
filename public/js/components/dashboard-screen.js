import { state } from "../store.js";
import { openEdit, signout, openSell, openEditAuction, loadMyAuctions, becomeSeller, startAuction } from "../actions.js";

const { onMounted, computed } = Vue;

export const DashboardScreen = {
  setup() {
    const isSeller = computed(() => state.user.role === "seller");
    onMounted(() => { if (isSeller.value) loadMyAuctions(); });
    const dollars = (cents) => (cents / 100).toFixed(2);
    return { state, isSeller, openEdit, signout, openSell, openEditAuction, becomeSeller, startAuction, dollars };
  },
  template: `
    <div class="card success">
      <div class="check">✓</div>
      <h1>Hi, {{ state.user.name }}</h1>
      <p class="subtitle">{{ isSeller ? 'Your seller dashboard.' : 'Welcome to Basic4.' }}</p>
      <div class="profile-row">
        <span class="profile-label">Account</span>
        <span class="profile-value">
          {{ isSeller ? 'Seller' : 'Buyer' }}
        </span>
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
        <button v-if="isSeller" @click="openSell">+ Sell a product at auction</button>
        <button v-else @click="becomeSeller" :disabled="state.submitting">Become a seller</button>
        <a class="link-button" href="/browse">Browse all auctions →</a>
      </div>

      <div class="auctions" v-if="isSeller && state.myAuctions.length">
        <h2>My auctions ({{ state.myAuctions.length }})</h2>
        <div class="auction-item" v-for="a in state.myAuctions" :key="a.id">
          <img class="auction-thumb" v-if="a.images && a.images.length" :src="a.images[0]" alt="">
          <div class="auction-text">
            <span class="auction-title">
              {{ a.title }}
              <span class="badge" :class="a.status">{{ a.status }}</span>
            </span>
            <span class="auction-meta">\${{ dollars(a.starting_price_cents) }} · {{ a.duration_days }}d</span>
          </div>
          <template v-if="a.status === 'draft'">
            <button type="button" class="auction-edit" @click="startAuction(a)" :disabled="state.submitting">Start</button>
            <button type="button" class="link-button auction-edit" @click="openEditAuction(a)">Edit</button>
          </template>
        </div>
      </div>

      <button type="button" class="link-button" @click="openEdit">Edit profile</button>
      <button type="button" class="link-button" @click="signout">Sign out</button>
    </div>
  `
};
