import { api } from "./api.js";

const { createApp, ref, reactive, onMounted } = Vue;

const App = {
  setup() {
    const products = ref([]);
    const me = ref(null);
    const loading = ref(true);
    const error = ref("");
    const bidAmount = reactive({}); // productId -> dollars string
    const bidError = reactive({});  // productId -> message

    const dollars = (cents) => (cents / 100).toFixed(2);
    const currentCents = (p) => p.current_bid_cents || p.starting_price_cents;

    // ends_at arrives as "YYYY-MM-DD HH:MM:SS UTC"; normalize to ISO for Date.
    const endsAtDate = (p) => (p.ends_at ? new Date(p.ends_at.replace(" UTC", "Z").replace(" ", "T")) : null);
    const isEnded = (p) => { const d = endsAtDate(p); return d && d < new Date(); };
    const canBid = (p) => p.status === "live" && !isEnded(p);
    const isOwn = (p) => me.value && me.value.id === p.seller_id;
    const isTopBidder = (p) => me.value && me.value.id === p.highest_bidder_id;

    const placeBid = async (p) => {
      bidError[p.id] = "";
      const amount_cents = Math.round(Number(bidAmount[p.id]) * 100);
      if (!Number.isFinite(amount_cents) || amount_cents <= 0) {
        bidError[p.id] = "Enter a bid amount.";
        return;
      }
      try {
        const { product } = await api(`/api/products/${p.id}/bid`, { method: "POST", body: { amount_cents } });
        const i = products.value.findIndex((x) => x.id === product.id);
        if (i !== -1) products.value.splice(i, 1, product);
        bidAmount[p.id] = "";
      } catch (e) {
        bidError[p.id] = e.message;
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
      products, me, loading, error, bidAmount, bidError,
      dollars, currentCents, isEnded, canBid, isOwn, isTopBidder, placeBid
    };
  },
  template: `
    <section class="browse">
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
              <span class="badge" :class="isEnded(p) ? 'draft' : p.status">{{ isEnded(p) ? 'ended' : p.status }}</span>
            </div>
            <h2 class="product-card-title">{{ p.title }}</h2>
            <p class="product-card-desc">{{ p.description }}</p>
            <div class="product-card-foot">
              <span class="product-price">\${{ dollars(currentCents(p)) }}</span>
              <span class="auction-meta">{{ p.bid_count > 0 ? p.bid_count + ' bid' + (p.bid_count === 1 ? '' : 's') : 'Starting bid' }}</span>
            </div>

            <div class="bid" v-if="canBid(p)">
              <p class="auction-meta" v-if="isOwn(p)">Your listing</p>
              <a class="link-button" v-else-if="!me" href="/">Sign in to bid →</a>
              <template v-else>
                <p class="bid-top" v-if="isTopBidder(p)">You're the top bidder</p>
                <div class="bid-row">
                  <input type="number" min="0" step="0.01" placeholder="Your bid (USD)" v-model="bidAmount[p.id]">
                  <button type="button" @click="placeBid(p)">Place bid</button>
                </div>
                <div class="error" v-if="bidError[p.id]">{{ bidError[p.id] }}</div>
              </template>
            </div>
          </div>
        </article>
      </div>
    </section>
  `
};

createApp(App).mount("#app");
