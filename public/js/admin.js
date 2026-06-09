import { api } from "./api.js";
import { currency } from "./format.js";

const { createApp, ref, computed, onMounted } = Vue;

// Back-office console. Three tabs:
//   • Closed auctions      — read-only catalogue of ended/completed listings.
//   • Settlements          — the work queue: every closed auction with a winner, with
//                            its current state and the next action the admin can take.
//   • Seller Applications  — buyers who submitted a credit score and await approval.
const SETTLEMENT_STEPS = ["invoiced", "paid", "shipped", "completed"];

// The next action for a settlement, given its current row. null once completed.
const nextAction = (row) => {
  const s = row.settlement;
  if (!s) return { label: "Invoice winner", path: `/api/admin/products/${row.product.id}/settlement` };
  if (s.status === "invoiced") return { label: "Mark payment received", path: `/api/admin/settlements/${s.id}/payment` };
  if (s.status === "paid") return { label: "Mark shipped", path: `/api/admin/settlements/${s.id}/shipment` };
  if (s.status === "shipped") return { label: "Release funds & complete", path: `/api/admin/settlements/${s.id}/complete` };
  return null;
};

const App = {
  setup() {
    const products = ref([]);
    const queue = ref([]);
    const applicants = ref([]);
    const me = ref(null);
    const loading = ref(true);
    const error = ref("");

    const view = ref("list");      // 'list' | 'settlements' | 'applications' | 'detail'
    const selected = ref(null);
    const selectedBids = ref([]);
    const seller = ref(null);
    const winner = ref(null);
    const settlement = ref(null);
    const detailError = ref("");
    const acting = ref(false);
    const actionError = ref("");
    const appError = ref("");

    const isAdmin = computed(() => me.value && me.value.role === "admin");
    const pendingCount = computed(() => queue.value.filter((r) => !r.settlement || r.settlement.status !== "completed").length);
    const applicantCount = computed(() => applicants.value.length);

    const currentCents = (p) => p.current_bid_cents || p.starting_price_cents;
    const bidLabel = (p) => (p.bid_count > 0 ? `${p.bid_count} bid${p.bid_count === 1 ? "" : "s"}` : "No bids");
    const statusBadge = (p) => (p && p.status === "completed" ? "completed" : "ended");
    const settlementState = (row) => (row.settlement ? row.settlement.status : "not started");
    const addressLines = (a) => (a ? [a.line1, a.line2, [a.city, a.region, a.postal_code].filter(Boolean).join(", "), a.country].filter(Boolean) : []);
    const stepReached = (status, step) => SETTLEMENT_STEPS.indexOf(status) >= SETTLEMENT_STEPS.indexOf(step);
    const nextActionFor = nextAction;

    const loadProducts = async () => { products.value = (await api("/api/admin/auctions")).products; };
    const loadQueue = async () => { queue.value = (await api("/api/admin/settlements")).items; };
    const loadApplicants = async () => { applicants.value = (await api("/api/admin/seller-applications")).applicants; };

    const loadDetail = async (id) => {
      const data = await api(`/api/admin/auctions/${id}`);
      selected.value = data.product;
      selectedBids.value = data.bids;
      seller.value = data.seller;
      winner.value = data.winner;
      settlement.value = data.settlement;
      const i = products.value.findIndex((x) => x.id === data.product.id);
      if (i !== -1) products.value.splice(i, 1, data.product);
    };

    const openDetail = async (idOrProduct) => {
      const id = typeof idOrProduct === "string" ? idOrProduct : idOrProduct.id;
      detailError.value = "";
      actionError.value = "";
      view.value = "detail";
      selected.value = typeof idOrProduct === "string" ? null : idOrProduct;
      selectedBids.value = [];
      seller.value = winner.value = settlement.value = null;
      try {
        await loadDetail(id);
      } catch (e) {
        detailError.value = e.message;
      }
    };

    const showList = () => { view.value = "list"; };
    const showSettlements = async () => { view.value = "settlements"; try { await loadQueue(); } catch (e) { error.value = e.message; } };
    const showApplications = async () => {
      view.value = "applications";
      appError.value = "";
      try { await loadApplicants(); } catch (e) { appError.value = e.message; }
    };

    const approveApplicant = async (id) => {
      acting.value = true;
      appError.value = "";
      try { await api(`/api/admin/seller-applications/${id}/approve`, { method: "POST" }); await loadApplicants(); }
      catch (e) { appError.value = e.message; }
      finally { acting.value = false; }
    };
    const rejectApplicant = async (id) => {
      acting.value = true;
      appError.value = "";
      try { await api(`/api/admin/seller-applications/${id}/reject`, { method: "POST" }); await loadApplicants(); }
      catch (e) { appError.value = e.message; }
      finally { acting.value = false; }
    };

    // POST a settlement action, then run the given refresh(es).
    const postAction = async (path, ...refreshers) => {
      acting.value = true;
      actionError.value = "";
      try {
        await api(path, { method: "POST" });
        for (const r of refreshers) await r();
      } catch (e) {
        actionError.value = e.message;
      } finally {
        acting.value = false;
      }
    };

    // Detail-view buttons (refresh the open auction).
    const invoiceWinner  = () => postAction(`/api/admin/products/${selected.value.id}/settlement`, () => loadDetail(selected.value.id));
    const recordPayment  = () => postAction(`/api/admin/settlements/${settlement.value.id}/payment`, () => loadDetail(selected.value.id));
    const recordShipment = () => postAction(`/api/admin/settlements/${settlement.value.id}/shipment`, () => loadDetail(selected.value.id));
    const completeOrder  = () => postAction(`/api/admin/settlements/${settlement.value.id}/complete`, () => loadDetail(selected.value.id));

    // Queue-row button (refresh the queue + the catalogue badges).
    const advanceRow = (row) => {
      const action = nextAction(row);
      if (action) postAction(action.path, loadQueue, loadProducts);
    };

    onMounted(async () => {
      try { me.value = (await api("/api/me")).user; } catch (_) { me.value = null; }
      if (!isAdmin.value) { loading.value = false; return; }
      try {
        await Promise.all([loadProducts(), loadQueue()]);
      } catch (e) {
        error.value = e.message;
      } finally {
        loading.value = false;
      }
    });

    return {
      products, queue, applicants, me, loading, error, isAdmin, pendingCount, applicantCount, view,
      selected, selectedBids, seller, winner, settlement, detailError, acting, actionError, appError,
      currency, currentCents, bidLabel, statusBadge, settlementState, addressLines,
      stepReached, nextActionFor, steps: SETTLEMENT_STEPS,
      openDetail, showList, showSettlements, showApplications, advanceRow,
      invoiceWinner, recordPayment, recordShipment, completeOrder,
      approveApplicant, rejectApplicant
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

      <template v-else>
        <!-- TABS -->
        <div class="admin-nav" v-if="view !== 'detail'">
          <button type="button" :class="{ active: view === 'list' }" @click="showList">Closed auctions</button>
          <button type="button" :class="{ active: view === 'settlements' }" @click="showSettlements">
            Settlements
            <span class="badge" v-if="pendingCount">{{ pendingCount }}</span>
          </button>
          <button type="button" :class="{ active: view === 'applications' }" @click="showApplications">
            Seller Applications
            <span class="badge" v-if="applicantCount">{{ applicantCount }}</span>
          </button>
        </div>

        <!-- CLOSED AUCTIONS LIST -->
        <template v-if="view === 'list'">
          <h1>Closed auctions</h1>
          <p class="subtitle">Settled listings across all sellers.</p>

          <div class="error" v-if="error">{{ error }}</div>
          <div class="card" v-else-if="!products.length">No closed auctions yet.</div>

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
                <a class="link-button" href="#" @click.prevent="openDetail(p)">View &amp; settle →</a>
              </div>
            </article>
          </div>
        </template>

        <!-- SETTLEMENTS QUEUE -->
        <template v-else-if="view === 'settlements'">
          <h1>Settlements</h1>
          <p class="subtitle">Auctions with a winner — invoice, payment, shipment, then release funds.</p>

          <div class="error" v-if="error">{{ error }}</div>
          <div class="card" v-else-if="!queue.length">No auctions to settle yet.</div>

          <div class="settlement-queue" v-else>
            <div class="settlement-row" v-for="row in queue" :key="row.product.id">
              <img class="settlement-thumb" v-if="row.product.images && row.product.images.length" :src="row.product.images[0]" alt="">
              <div class="settlement-thumb is-empty" v-else></div>

              <div class="settlement-row-main">
                <span class="settlement-row-title">{{ row.product.title }}</span>
                <span class="auction-meta">
                  {{ currency(currentCents(row.product)) }} · winner: {{ row.winner ? row.winner.name : 'unknown' }}
                </span>
                <div class="settlement-steps">
                  <span class="settlement-step" v-for="s in steps" :key="s"
                        :class="{ done: row.settlement && stepReached(row.settlement.status, s) }">{{ s }}</span>
                </div>
              </div>

              <div class="settlement-row-action">
                <button type="button" v-if="nextActionFor(row)" @click="advanceRow(row)" :disabled="acting">
                  {{ nextActionFor(row).label }}
                </button>
                <span class="sold" v-else>Completed ✓</span>
                <a class="link-button" href="#" @click.prevent="openDetail(row.product)">Details →</a>
              </div>
            </div>
          </div>
        </template>

        <!-- SELLER APPLICATIONS -->
        <template v-else-if="view === 'applications'">
          <h1>Seller Applications</h1>
          <p class="subtitle">Buyers who completed credit scoring and are awaiting approval.</p>

          <div class="error" v-if="appError">{{ appError }}</div>
          <div class="card" v-else-if="!applicants.length">No pending applications.</div>

          <div class="settlement-queue" v-else>
            <div class="settlement-row" v-for="a in applicants" :key="a.id">
              <div class="settlement-row-main">
                <span class="settlement-row-title">{{ a.name }}</span>
                <span class="auction-meta">{{ a.email }}</span>
                <span class="auction-meta" v-if="a.credit_score">
                  Credit score: <strong>{{ a.credit_score.score }}</strong>
                  &middot; submitted {{ new Date(a.credit_score.computed_at).toLocaleDateString() }}
                </span>
              </div>
              <div class="settlement-row-action">
                <button type="button" class="btn-approve" @click="approveApplicant(a.id)" :disabled="acting">Approve</button>
                <button type="button" class="btn-reject"  @click="rejectApplicant(a.id)"  :disabled="acting">Reject</button>
              </div>
            </div>
          </div>
        </template>

        <!-- DETAIL -->
        <template v-else-if="selected">
          <a class="link-button" href="#" @click.prevent="showList">← All closed auctions</a>
          <div class="detail">
            <img class="detail-img" v-if="selected.images && selected.images.length" :src="selected.images[0]" :alt="selected.title">
            <div class="product-card-tags">
              <span class="badge">{{ selected.category }}</span>
              <span class="badge" :class="statusBadge(selected)">{{ statusBadge(selected) }}</span>
            </div>
            <h1>{{ selected.title }}</h1>
            <p class="detail-desc">{{ selected.description }}</p>

            <div class="profile-row">
              <span class="profile-label">{{ selected.bid_count > 0 ? 'Final bid' : 'Starting price' }}</span>
              <span class="profile-value">{{ currency(currentCents(selected)) }} · {{ bidLabel(selected) }}</span>
            </div>

            <!-- PARTIES -->
            <div class="party-grid">
              <div class="card party-card">
                <h3>Seller</h3>
                <template v-if="seller">
                  <p class="party-name">{{ seller.name }}</p>
                  <p class="party-line">{{ seller.email }}</p>
                </template>
                <p class="auction-meta" v-else>Unknown</p>
              </div>
              <div class="card party-card">
                <h3>Winner</h3>
                <template v-if="winner">
                  <p class="party-name">{{ winner.name }}</p>
                  <p class="party-line">{{ winner.email }}</p>
                  <p class="party-line" v-for="(l, i) in addressLines(winner.shipping_address)" :key="i">{{ l }}</p>
                  <p class="party-line" v-if="!winner.shipping_address"><em>No shipping address on file</em></p>
                </template>
                <p class="auction-meta" v-else>No winner — nothing to settle.</p>
              </div>
            </div>

            <!-- SETTLEMENT -->
            <div class="card settlement" v-if="winner">
              <h2>Settlement</h2>
              <div class="error" v-if="actionError">{{ actionError }}</div>

              <template v-if="settlement">
                <div class="settlement-steps">
                  <span class="settlement-step" v-for="s in steps" :key="s"
                        :class="{ done: stepReached(settlement.status, s) }">{{ s }}</span>
                </div>
                <p class="profile-value">Amount: {{ currency(settlement.amount_cents) }}</p>

                <button type="button" v-if="settlement.status === 'invoiced'" @click="recordPayment" :disabled="acting">Mark payment received</button>
                <button type="button" v-else-if="settlement.status === 'paid'" @click="recordShipment" :disabled="acting">Mark shipped</button>
                <button type="button" v-else-if="settlement.status === 'shipped'" @click="completeOrder" :disabled="acting">Release funds &amp; complete</button>
                <p class="sold" v-else>Settlement complete ✓</p>
              </template>

              <template v-else>
                <p class="auction-meta">No settlement yet.</p>
                <button type="button" @click="invoiceWinner" :disabled="acting">Invoice winner</button>
              </template>
            </div>

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
      </template>
    </section>
  `
};

createApp(App).mount("#app");
