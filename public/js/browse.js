import { api } from "./api.js";
import { currency, digitsToCents } from "./format.js";

const { createApp, ref, computed, onMounted } = Vue;

const App = {
  setup() {
    const products = ref([]);
    const me = ref(null);
    const loading = ref(true);
    const error = ref("");

    const view = ref("list");          // 'list' | 'detail'
    const selected = ref(null);        // product in detail view
    const selectedBids = ref([]);
    const detailError = ref("");
    const bidCents = ref(0);
    const bidError = ref("");
    const bidDisplay = computed(() => (bidCents.value ? currency(bidCents.value) : ""));
    const onBidInput = (e) => {
      bidCents.value = digitsToCents(e.target.value);
      e.target.value = bidDisplay.value; // re-mask in place ("" -> placeholder)
    };

    const currentCents = (p) => p.current_bid_cents || p.starting_price_cents;

    // ends_at arrives as "YYYY-MM-DD HH:MM:SS UTC"; normalize to ISO for Date.
    const endsAtDate = (p) => (p && p.ends_at ? new Date(p.ends_at.replace(" UTC", "Z").replace(" ", "T")) : null);
    const isEnded = (p) => { const d = endsAtDate(p); return d && d < new Date(); };
    // stopped, settled, or time-expired — bidding is over either way
    const isClosed = (p) => p && (p.status === "ended" || p.status === "completed" || isEnded(p));
    // Badge text/class: a settled auction reads "completed"; anything else closed reads "ended".
    const statusBadge = (p) => (p && p.status === "completed" ? "completed" : (isClosed(p) ? "ended" : p.status));
    const canBid = (p) => p && p.status === "live" && !isEnded(p);
    const isOwn = (p) => me.value && p && me.value.id === p.seller_id;
    const isTopBidder = (p) => me.value && p && me.value.id === p.highest_bidder_id;
    const bidLabel = (p) => (p.bid_count > 0 ? `${p.bid_count} bid${p.bid_count === 1 ? "" : "s"}` : "Starting bid");

    const loadDetail = async (id) => {
      const data = await api(`/api/products/${id}`);
      selected.value = data.product;
      selectedBids.value = data.bids;
    };

    const openDetail = async (p) => {
      detailError.value = "";
      bidError.value = "";
      bidCents.value = 0;
      view.value = "detail";
      selected.value = p;        // show immediately; refresh with bids below
      selectedBids.value = [];
      try {
        await loadDetail(p.id);
      } catch (e) {
        detailError.value = e.message;
      }
    };

    const backToList = () => { view.value = "list"; selected.value = null; };

    const placeBid = async () => {
      bidError.value = "";
      const amount_cents = bidCents.value;
      if (amount_cents <= 0) {
        bidError.value = "Enter a bid amount.";
        return;
      }
      try {
        await api(`/api/products/${selected.value.id}/bid`, { method: "POST", body: { amount_cents } });
        bidCents.value = 0;
        await loadDetail(selected.value.id);                 // refresh product + bids
        const i = products.value.findIndex((x) => x.id === selected.value.id);
        if (i !== -1) products.value.splice(i, 1, selected.value); // keep grid summary fresh
      } catch (e) {
        bidError.value = e.message;
      }
    };

    onMounted(async () => {
      try { me.value = (await api("/api/me")).user; } catch (_) { me.value = null; }
      try {
        products.value = (await api("/api/products")).products;
      } catch (e) {
        error.value = e.message;
      } finally {
        loading.value = false;
      }
    });

    return {
      products, me, loading, error, view, selected, selectedBids, detailError,
      bidDisplay, onBidInput, bidError, currency, currentCents, isEnded, isClosed, statusBadge, canBid, isOwn, isTopBidder,
      bidLabel, openDetail, backToList, placeBid
    };
  },
  template: `
    <section class="browse">
      <!-- LIST -->
      <template v-if="view === 'list'">
        <h1>Browse auctions</h1>
        <p class="subtitle">Live listings from all Basic4 sellers.</p>

        <div class="card" v-if="loading">Loading…</div>
        <div class="error" v-else-if="error">{{ error }}</div>
        <div class="card" v-else-if="!products.length">No auctions listed yet.</div>

        <div class="product-grid" v-else>
          <article class="product-card" v-for="p in products" :key="p.id">
            <img class="product-card-img" v-if="p.images && p.images.length" :src="p.images[0]" :alt="p.title">
            <div class="product-card-img is-empty" v-else>No photo</div>
            <div class="product-card-body">
              <div class="product-card-tags">
                <span class="badge">{{ p.category }}</span>
                <span class="badge" :class="statusBadge(p)">{{ statusBadge(p) }}</span>
              </div>
              <h2 class="product-card-title">{{ p.title }}</h2>
              <p class="product-card-desc">{{ p.description }}</p>
              <div class="product-card-foot">
                <span class="product-price">{{ currency(currentCents(p)) }}</span>
                <span class="auction-meta">{{ bidLabel(p) }}</span>
              </div>
              <a class="link-button" href="#" @click.prevent="openDetail(p)">View &amp; bid →</a>
            </div>
          </article>
        </div>
      </template>

      <!-- DETAIL -->
      <template v-else-if="selected">
        <a class="link-button" href="#" @click.prevent="backToList">← All auctions</a>
        <div class="detail">
          <img class="detail-img" v-if="selected.images && selected.images.length" :src="selected.images[0]" :alt="selected.title">
          <div class="product-card-tags">
            <span class="badge">{{ selected.category }}</span>
            <span class="badge" :class="statusBadge(selected)">{{ statusBadge(selected) }}</span>
          </div>
          <h1>{{ selected.title }}</h1>
          <p class="detail-desc">{{ selected.description }}</p>

          <div class="profile-row">
            <span class="profile-label">{{ selected.bid_count > 0 ? 'Current bid' : 'Starting price' }}</span>
            <span class="profile-value">{{ currency(currentCents(selected)) }} · {{ bidLabel(selected) }}</span>
          </div>

          <div class="bid" v-if="canBid(selected)">
            <p class="auction-meta" v-if="isOwn(selected)">Your listing</p>
            <a class="link-button" v-else-if="!me" href="/app">Sign in to bid →</a>
            <template v-else>
              <p class="bid-top" v-if="isTopBidder(selected)">You're the top bidder</p>
              <div class="bid-row">
                <input type="text" inputmode="numeric" placeholder="$0.00" :value="bidDisplay" @input="onBidInput">
                <button type="button" @click="placeBid">Place bid</button>
              </div>
              <div class="error" v-if="bidError">{{ bidError }}</div>
            </template>
          </div>
          <template v-else-if="isClosed(selected)">
            <p class="sold" v-if="selectedBids.length">Sold for {{ currency(selectedBids[0].amount_cents) }} to {{ selectedBids[0].bidder }}</p>
            <p class="auction-meta" v-else>Ended — no bids</p>
          </template>
          <p class="auction-meta" v-else>Not started yet.</p>

          <h2>Bids</h2>
          <div class="error" v-if="detailError">{{ detailError }}</div>
          <p class="auction-meta" v-else-if="!selectedBids.length">No bids yet.</p>
          <div class="bid-list" v-else>
            <div class="bid-list-row" v-for="b in selectedBids" :key="b.id" :class="{ mine: b.mine }">
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
