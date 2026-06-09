import { state } from "../store.js";
import {
  openEdit, signout, openSell, openEditAuction,
  loadMyAuctions, becomeSeller, startAuction, stopAuction,
  loadNotifications, toggleNotificationPanel, markNotificationRead,
  loadUnreadCount
} from "../actions.js";
import { currency } from "../format.js";

const { onMounted, onUnmounted, computed, ref } = Vue;

export const DashboardScreen = {
  setup() {
    const isSeller = computed(() => state.user.role === "seller");
    const isAdmin  = computed(() => state.user.role === "admin");

    let pollHandle = null;

    const refreshAll = () => {
      if (isSeller.value) loadMyAuctions();
      loadUnreadCount();
    };

    onMounted(() => {
      refreshAll();
      // Poll for new notifications every 30s.
      pollHandle = setInterval(refreshAll, 30000);
    });

    onUnmounted(() => {
      if (pollHandle) clearInterval(pollHandle);
    });

    const formatTime = (iso) => {
      if (!iso) return "";
      const d = new Date(iso);
      const diff = Math.floor((Date.now() - d.getTime()) / 1000);
      if (diff < 60) return "just now";
      if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
      if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
      return d.toLocaleDateString();
    };

    // Status badge for a product listing. Returns label + class for the badge.
    const statusInfo = (a) => {
      switch (a.status) {
        case "pending_approval": return { label: "awaiting approval", cls: "pending_approval" };
        case "rejected":         return { label: "rejected", cls: "rejected" };
        case "draft":            return { label: "approved · ready", cls: "draft" };
        case "live":             return { label: "live", cls: "live" };
        case "ended":            return { label: "ended", cls: "ended" };
        case "completed":        return { label: "completed", cls: "completed" };
        default:                 return { label: a.status, cls: a.status };
      }
    };

    const notificationIcon = (type) => {
      switch (type) {
        case "product_pending_approval": return "📦";
        case "product_approved":         return "✅";
        case "product_rejected":         return "⚠️";
        default: return "🔔";
      }
    };

    const handleNotificationClick = (n) => {
      if (!n.read) markNotificationRead(n.id);
      state.notificationPanelOpen = false;
    };

    return {
      state, isSeller, isAdmin,
      openEdit, signout, openSell, openEditAuction,
      becomeSeller, startAuction, stopAuction,
      loadNotifications, toggleNotificationPanel, markNotificationRead,
      formatTime, statusInfo, notificationIcon, handleNotificationClick,
      currency
    };
  },

  template: `
    <div class="card success">
      <!-- ── Notification bell ───────────────────────────────────── -->
      <div class="notif-bell-wrapper" v-if="!isAdmin">
        <button type="button" class="notif-bell" @click="toggleNotificationPanel" aria-label="Notifications">
          🔔
          <span class="notif-badge" v-if="state.unreadCount > 0">{{ state.unreadCount }}</span>
        </button>
        <div class="notif-panel" v-if="state.notificationPanelOpen" @click.stop>
          <div class="notif-panel-header">
            <strong>Notifications</strong>
            <button type="button" class="link-button" @click="toggleNotificationPanel">×</button>
          </div>
          <div class="notif-list" v-if="state.notifications.length">
            <div class="notif-item"
                 v-for="n in state.notifications" :key="n.id"
                 :class="{ unread: !n.read }"
                 @click="handleNotificationClick(n)">
              <span class="notif-icon">{{ notificationIcon(n.type) }}</span>
              <div class="notif-body">
                <div class="notif-title">{{ n.title }}</div>
                <div class="notif-msg">{{ n.body }}</div>
                <div class="notif-time">{{ formatTime(n.created_at) }}</div>
              </div>
            </div>
          </div>
          <div class="notif-empty" v-else>No notifications yet.</div>
        </div>
      </div>

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
              <span class="badge" :class="statusInfo(a).cls">{{ statusInfo(a).label }}</span>
            </span>

            <span class="auction-meta" v-if="a.status === 'live'">
              {{ currency(a.current_bid_cents || a.starting_price_cents) }} · {{ a.bid_count }} bid{{ a.bid_count === 1 ? '' : 's' }}
            </span>
            <span class="auction-meta" v-else-if="a.status === 'ended' || a.status === 'completed'">
              {{ a.current_bid_cents ? 'Sold for ' + currency(a.current_bid_cents) + ' · ' + a.bid_count + ' bid' + (a.bid_count === 1 ? '' : 's') : 'Ended — no bids' }}
            </span>
            <span class="auction-meta" v-else-if="a.status === 'pending_approval'">
              Awaiting admin approval before you can start the auction.
            </span>
            <span class="auction-meta" v-else-if="a.status === 'rejected'">
              <span class="rejection-reason">Reason: {{ a.rejection_reason }}</span>
              Edit and resubmit for another review.
            </span>
            <span class="auction-meta" v-else>
              {{ currency(a.starting_price_cents) }} · {{ a.duration_days }}d
            </span>
          </div>

          <template v-if="a.status === 'pending_approval'">
            <button type="button" class="link-button auction-edit" @click="openEditAuction(a)">Edit</button>
          </template>
          <template v-else-if="a.status === 'rejected'">
            <button type="button" class="auction-edit" @click="openEditAuction(a)" :disabled="state.submitting">Edit & Resubmit</button>
          </template>
          <template v-else-if="a.status === 'draft'">
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
