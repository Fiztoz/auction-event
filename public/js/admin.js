import { api } from "./api.js";
import { currency } from "./format.js";

const { createApp, ref, computed, onMounted } = Vue;

// Read-only back-office console. Admins may only see closed (ended) auctions,
// so the list is fed by /api/admin/auctions and there is no bidding UI.
const App = {
  setup() {
    const products = ref([]);
    const me = ref(null);
    const loading = ref(true);
    const error = ref("");

    const view = ref("list");      // 'list' | 'detail'
    const selected = ref(null);
    const selectedBids = ref([]);
    const detailError = ref("");

    const isAdmin = computed(() => me.value && me.value.role === "admin");
    const currentCents = (p) => p.current_bid_cents || p.starting_price_cents;
    const bidLabel = (p) => (p.bid_count > 0 ? `${p.bid_count} bid${p.bid_count === 1 ? "" : "s"}` : "No bids");

    const openDetail = async (p) => {
      detailError.value = "";
      view.value = "detail";
      selected.value = p;
      selectedBids.value = [];
      try {
        const data = await api(`/api/products/${p.id}`);
        selected.value = data.product;
        selectedBids.value = data.bids;
      } catch (e) {
        detailError.value = e.message;
      }
    };

    const backToList = () => { view.value = "list"; selected.value = null; };

    onMounted(async () => {
      try { me.value = (await api("/api/me")).user; } catch (_) { me.value = null; }
      if (!isAdmin.value) { loading.value = false; return; }
      try {
        products.value = (await api("/api/admin/auctions")).products;
      } catch (e) {
        error.value = e.message;
      } finally {
        loading.value = false;
      }
    });

    return {
      products, me, loading, error, isAdmin, view, selected, selectedBids,
      detailError, currency, currentCents, bidLabel, openDetail, backToList
    };
  },
  template: `
    <section class="browse">
      <div class="card" v-if="loading">Loading…</div>

      <!-- GATE: admins only -->
      <div class="card" v-else-if="!isAdmin">
        <h1>Admin console</h1>
        <p class="subtitle">This area is for administrators only.</p>
        <a class="link-button" href="/app">Sign in →</a>
      </div>

      <!-- LIST -->
      <template v-else-if="view === 'list'">
        <h1>Closed auctions</h1>
        <p class="subtitle">Settled listings across all sellers — read only.</p>

        <div class="error" v-if="error">{{ error }}</div>
        <div class="card" v-else-if="!products.length">No closed auctions yet.</div>

        <div class="product-grid" v-else>
          <article class="product-card" v-for="p in products" :key="p.id">
            <img class="product-card-img" v-if="p.images && p.images.length" :src="p.images[0]" :alt="p.title">
            <div class="product-card-img is-empty" v-else>No photo</div>
            <div class="product-card-body">
              <div class="product-card-tags">
                <span class="badge">{{ p.category }}</span>
                <span class="badge ended">ended</span>
              </div>
              <h2 class="product-card-title">{{ p.title }}</h2>
              <p class="product-card-desc">{{ p.description }}</p>
              <div class="product-card-foot">
                <span class="product-price">{{ currency(currentCents(p)) }}</span>
                <span class="auction-meta">{{ bidLabel(p) }}</span>
              </div>
              <a class="link-button" href="#" @click.prevent="openDetail(p)">View details →</a>
            </div>
          </article>
        </div>
      </template>

      <!-- DETAIL -->
      <template v-else-if="selected">
        <a class="link-button" href="#" @click.prevent="backToList">← All closed auctions</a>
        <div class="detail">
          <img class="detail-img" v-if="selected.images && selected.images.length" :src="selected.images[0]" :alt="selected.title">
          <div class="product-card-tags">
            <span class="badge">{{ selected.category }}</span>
            <span class="badge ended">ended</span>
          </div>
          <h1>{{ selected.title }}</h1>
          <p class="detail-desc">{{ selected.description }}</p>

          <div class="profile-row">
            <span class="profile-label">{{ selected.bid_count > 0 ? 'Final bid' : 'Starting price' }}</span>
            <span class="profile-value">{{ currency(currentCents(selected)) }} · {{ bidLabel(selected) }}</span>
          </div>

          <p class="sold" v-if="selectedBids.length">Sold for {{ currency(selectedBids[0].amount_cents) }} to {{ selectedBids[0].bidder }}</p>
          <p class="auction-meta" v-else>Ended — no bids</p>

          <h2>Bids</h2>
          <div class="error" v-if="detailError">{{ detailError }}</div>
          <p class="auction-meta" v-else-if="!selectedBids.length">No bids yet.</p>
          <div class="bid-list" v-else>
            <div class="bid-list-row" v-for="b in selectedBids" :key="b.id">
              <span class="bid-list-amount">{{ currency(b.amount_cents) }}</span>
              <span class="bid-list-bidder">{{ b.bidder }}</span>
            </div>
          </div>
        </div>
      </template>
    </section>
  `
};

createApp(App).mount("#app");
