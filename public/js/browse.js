import { api } from "./api.js";

const { createApp, ref, onMounted } = Vue;

const App = {
  setup() {
    const products = ref([]);
    const loading = ref(true);
    const error = ref("");
    const dollars = (cents) => (cents / 100).toFixed(2);

    onMounted(async () => {
      try {
        const { products: list } = await api("/api/products");
        products.value = list;
      } catch (e) {
        error.value = e.message;
      } finally {
        loading.value = false;
      }
    });

    return { products, loading, error, dollars };
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
            <span class="badge">{{ p.category }}</span>
            <h2 class="product-card-title">{{ p.title }}</h2>
            <p class="product-card-desc">{{ p.description }}</p>
            <div class="product-card-foot">
              <span class="product-price">\${{ dollars(p.starting_price_cents) }}</span>
              <span class="auction-meta">{{ p.status }} · {{ p.duration_days }}d</span>
            </div>
          </div>
        </article>
      </div>
    </section>
  `
};

createApp(App).mount("#app");
