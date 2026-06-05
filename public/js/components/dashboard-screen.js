import { state } from "../store.js";
import { openEdit, signout, openSell, openEditAuction, loadMyAuctions, becomeSeller, startAuction, stopAuction } from "../actions.js";
import { currency } from "../format.js";

const { onMounted, computed } = Vue;

export const DashboardScreen = {
  setup() {
    const isSeller = computed(() => state.user.role === "seller");
    const isAdmin = computed(() => state.user.role === "admin");
    onMounted(() => { if (isSeller.value) loadMyAuctions(); });
    return { state, isSeller, isAdmin, openEdit, signout, openSell, openEditAuction, becomeSeller, startAuction, stopAuction, currency };
  },
  template: `
    <div class="card success">
      <div class="check">✓</div>
      <h1>Hi, {{ state.user.name }}</h1>
      <p class="subtitle">{{ isAdmin ? 'Administrator account.' : isSeller ? 'Your seller dashboard.' : 'Welcome to Basic4.' }}</p>
      <div class="profile-row">
        <span class="profile-label">Account</span>
        <span class="profile-value">
          {{ isAdmin ? 'Admin' : isSeller ? 'Seller' : 'Buyer' }}
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
        <a v-if="isAdmin" class="link-button" href="/admin">Open admin console →</a>
        <template v-else>
          <button v-if="isSeller" @click="openSell">+ Sell a product at auction</button>
          <button v-else @click="becomeSeller" :disabled="state.submitting">Become a seller</button>
        </template>
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
            <span class="auction-meta" v-if="a.status === 'live'">
              {{ currency(a.current_bid_cents || a.starting_price_cents) }} · {{ a.bid_count }} bid{{ a.bid_count === 1 ? '' : 's' }}
            </span>
            <span class="auction-meta" v-else-if="a.status === 'ended' || a.status === 'completed'">
              {{ a.current_bid_cents ? 'Sold for ' + currency(a.current_bid_cents) + ' · ' + a.bid_count + ' bid' + (a.bid_count === 1 ? '' : 's') : 'Ended — no bids' }}
            </span>
            <span class="auction-meta" v-else>{{ currency(a.starting_price_cents) }} · {{ a.duration_days }}d</span>
          </div>
          <template v-if="a.status === 'draft'">
            <button type="button" class="auction-edit" @click="startAuction(a)" :disabled="state.submitting">Start</button>
            <button type="button" class="link-button auction-edit" @click="openEditAuction(a)">Edit</button>
          </template>
          <button type="button" v-else-if="a.status === 'live'" class="link-button auction-edit" @click="stopAuction(a)" :disabled="state.submitting">Stop</button>
        </div>
      </div>

      <button type="button" class="link-button" @click="openEdit">Edit profile</button>
      <button type="button" class="link-button" @click="signout">Sign out</button>
    </div>
  `
};
