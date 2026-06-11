/**
 * SSE Service for Admin Dashboard
 * Replaces polling with real-time Server-Sent Events.
 * When the backend processes a RabbitMQ event, it broadcasts via SSE
 * and this client updates the DOM immediately.
 */

const SSEService = {
  // Configuration
  config: {
    url: '/api/events/stream',
    reconnectBaseDelay: 1000,
    reconnectMaxDelay: 30000,
    heartbeatTimeout: 60000
  },

  // State
  state: {
    eventSource: null,
    reconnectAttempts: 0,
    reconnectTimer: null,
    heartbeatTimer: null,
    lastEventTime: null,
    isPaused: false
  },

  // Map event types to the dashboard sections they affect
  // When an event arrives, we fetch fresh data for the affected section
  eventSectionMap: {
    'product.listed': ['approvalQueue', 'overview'],
    'product.approved': ['approvalQueue', 'auctions', 'overview'],
    'product.rejected': ['approvalQueue', 'overview'],
    'auction.started': ['auctions', 'overview'],
    'auction.ended': ['auctions', 'settlements', 'overview'],
    'bid.placed': ['auctions', 'bidActivity', 'overview'],
    'settlement.created': ['settlements', 'overview'],
    'settlement.invoiced': ['settlements', 'overview'],
    'settlement.paid': ['settlements', 'overview'],
    'settlement.shipped': ['settlements', 'overview'],
    'settlement.completed': ['settlements', 'overview'],
    'user.registered': ['overview']
  },

  // API endpoints for fetching fresh data
  endpoints: {
    overview: '/api/reports/overview',
    approvalQueue: '/api/reports/approval-queue',
    settlements: '/api/reports/settlements',
    activeAuctions: '/api/reports/active-auctions',
    auctions: '/api/reports/active-auctions',
    sellers: '/api/reports/sellers',
    bidActivity: '/api/reports/bid-activity',
    myListings: '/api/reports/my-listings',
    myRevenue: '/api/reports/my-revenue',
    myBids: '/api/reports/my-bids',
    myWon: '/api/reports/my-won'
  },

  /**
   * Initialize SSE for the current page
   * Uses localStorage to ensure only the newest tab holds an SSE connection.
   */
  init(page) {
    console.log(`🔌 Initializing SSE for: ${page}`);
    this.currentPage = page;
    this.state.tabId = `tab_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

    // Register this tab as active
    this._registerTab();

    // Only connect if this tab is the leader (newest)
    if (this._isLeader()) {
      this.connect();
    } else {
      console.log('⏸️ Not the leader tab, SSE deferred');
      this.updateConnectionStatus('disconnected');
    }

    // Clean up on page unload
    window.addEventListener('beforeunload', () => {
      this._unregisterTab();
      this.disconnect();
    });

    // When tab becomes visible, re-check leadership
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) {
        this._registerTab(); // Refresh timestamp
        if (this._isLeader() && !this.state.eventSource) {
          console.log('▶️ Tab became visible, claiming SSE leadership');
          this.connect();
        }
      }
    });
  },

  /**
   * Register this tab in localStorage with current timestamp
   */
  _registerTab() {
    try {
      localStorage.setItem(`sse_${this.state.tabId}`, Date.now().toString());
    } catch (e) { /* localStorage unavailable */ }
  },

  /**
   * Remove this tab from localStorage
   */
  _unregisterTab() {
    try {
      localStorage.removeItem(`sse_${this.state.tabId}`);
    } catch (e) { /* localStorage unavailable */ }
  },

  /**
   * Check if this tab is the leader (newest active tab)
   */
  _isLeader() {
    try {
      const now = Date.now();
      const staleThreshold = 30000; // 30s — consider tab dead if no refresh
      let newestTime = 0;
      let newestKey = null;

      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith('sse_tab_')) {
          const ts = parseInt(localStorage.getItem(key), 10);
          if (isNaN(ts)) continue;
          // Clean up stale entries
          if (now - ts > staleThreshold) {
            localStorage.removeItem(key);
            continue;
          }
          if (ts > newestTime) {
            newestTime = ts;
            newestKey = key;
          }
        }
      }
      return newestKey === `sse_${this.state.tabId}`;
    } catch (e) {
      return true; // If localStorage fails, allow connection
    }
  },

  /**
   * Disconnect from SSE cleanly
   */
  disconnect() {
    if (this.state.eventSource) {
      this.state.eventSource.close();
      this.state.eventSource = null;
    }
    if (this.state.reconnectTimer) {
      clearTimeout(this.state.reconnectTimer);
      this.state.reconnectTimer = null;
    }
    clearInterval(this.state.heartbeatTimer);
  },

  /**
   * Connect to SSE endpoint
   */
  connect() {
    if (this.state.eventSource) {
      this.state.eventSource.close();
    }

    console.log('🔌 Connecting to SSE stream...');
    this.state.eventSource = new EventSource(this.config.url);

    // Connection established
    this.state.eventSource.addEventListener('connected', (e) => {
      console.log('✅ SSE connected:', JSON.parse(e.data));
      this.state.reconnectAttempts = 0;
      this.updateConnectionStatus('connected');
      this.startHeartbeatMonitor();
    });

    // Listen for ALL event types from the backend
    // The backend sends events like: event: product.listed\ndata: {...}
    // We listen for each specific event type
    const eventTypes = [
      'product.listed', 'product.approved', 'product.rejected',
      'auction.started', 'auction.ended', 'bid.placed',
      'settlement.created', 'settlement.invoiced', 'settlement.paid',
      'settlement.shipped', 'settlement.completed', 'user.registered'
    ];

    eventTypes.forEach(eventType => {
      this.state.eventSource.addEventListener(eventType, (e) => {
        this.handleEvent(eventType, JSON.parse(e.data));
      });
    });

    // Generic message handler (for any events we didn't register specifically)
    this.state.eventSource.onmessage = (e) => {
      try {
        const data = JSON.parse(e.data);
        if (data.event_type) {
          this.handleEvent(data.event_type, data);
        }
      } catch (err) {
        console.warn('Failed to parse SSE message:', err);
      }
    };

    // Error handling - let EventSource auto-reconnect natively
    // DO NOT close or scheduleReconnect here — that fights the built-in reconnector
    // and creates duplicate connection stacks.
    this.state.eventSource.onerror = (e) => {
      console.warn('⚠️ SSE error (auto-reconnecting):', e);
      this.updateConnectionStatus('disconnected');
    };
  },

  /**
   * Handle an incoming SSE event
   */
  handleEvent(eventType, payload) {
    if (this.state.isPaused) return;

    console.log(`📨 SSE event: ${eventType}`, payload);
    this.state.lastEventTime = new Date();
    this.updateConnectionStatus('connected');

    // Determine which sections need updating
    const sections = this.eventSectionMap[eventType] || [];

    // Fetch fresh data for affected sections
    sections.forEach(section => {
      this.fetchAndUpdate(section);
    });

    // Show a subtle notification
    this.showEventNotification(eventType);
  },

  /**
   * Fetch fresh data for a section and update DOM
   */
  async fetchAndUpdate(section) {
    const url = this.endpoints[section];
    if (!url) return;

    try {
      // Add seller_id/buyer_id params for personalized pages
      let fetchUrl = url;
      if (section === 'myListings' || section === 'myRevenue') {
        const sellerId = this.getUrlParam('seller_id');
        if (sellerId) fetchUrl += `?seller_id=${sellerId}`;
        else return; // No seller_id, skip
      }
      if (section === 'myBids' || section === 'myWon') {
        const buyerId = this.getUrlParam('buyer_id');
        if (buyerId) fetchUrl += `?buyer_id=${buyerId}`;
        else return;
      }

      const response = await fetch(fetchUrl);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();

      // Call the appropriate update function
      const updateFn = this.getUpdateFunction(section);
      if (updateFn) updateFn(data);

      this.showLastUpdated();
    } catch (error) {
      console.error(`SSE fetch error for ${section}:`, error);
    }
  },

  /**
   * Get the DOM update function for a section
   */
  getUpdateFunction(section) {
    const map = {
      overview: this.updateOverview.bind(this),
      approvalQueue: this.updateApprovalQueue.bind(this),
      settlements: this.updateSettlements.bind(this),
      auctions: this.updateAuctions.bind(this),
      sellers: this.updateSellers.bind(this),
      myListings: this.updateMyListings.bind(this),
      myRevenue: this.updateMyRevenue.bind(this),
      myBids: this.updateMyBids.bind(this),
      myWon: this.updateMyWon.bind(this)
    };
    return map[section];
  },

  // === DOM UPDATE FUNCTIONS (same as old PollingService) ===

  updateOverview(data) {
    const overview = data.overview;
    if (!overview || !Array.isArray(overview) || overview.length === 0) return;
    const metrics = overview[0];
    this.updateElement('stat-users', this.formatNumber(metrics.total_users || 0));
    this.updateElement('stat-auctions', this.formatNumber(metrics.active_auctions || 0));
    this.updateElement('stat-revenue', this.formatCurrency(metrics.total_revenue_cents || 0));
    this.updateElement('stat-bids', this.formatNumber(metrics.total_bids || 0));
    this.updateElement('stat-new-users', this.formatNumber(metrics.new_users || 0));
    this.updateElement('stat-settlements', this.formatNumber(metrics.settlements_completed || 0));
  },

  updateApprovalQueue(data) {
    const products = data.products || [];
    const container = document.getElementById('approval-list');
    if (!container) return;
    if (products.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>🎉 No products pending approval</p></div>';
      return;
    }
    container.innerHTML = products.map(product => `
      <tr>
        <td><strong>${this.escapeHtml(product.title)}</strong></td>
        <td>${this.escapeHtml(product.seller_name)}</td>
        <td><span class="badge badge-secondary">${this.escapeHtml(product.category)}</span></td>
        <td>${this.formatCurrency(product.price_cents)}</td>
        <td>${this.timeAgo(product.created_at)}</td>
        <td><span class="badge badge-warning">Pending</span></td>
      </tr>
    `).join('');
    this.updateElement('pending-count', products.length);
  },

  updateSettlements(data) {
    const settlements = data.settlements || [];
    const container = document.getElementById('settlements-list');
    if (!container) return;
    if (settlements.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>📦 No settlements in pipeline</p></div>';
      return;
    }
    container.innerHTML = settlements.map(settlement => `
      <div class="settlement-card">
        <div class="settlement-header">
          <h3>${this.escapeHtml(settlement.product_title)}</h3>
          <span class="badge ${this.statusBadgeClass(settlement.status)}">${settlement.status}</span>
        </div>
        <div class="settlement-details">
          <div class="detail-row"><span class="label">Seller:</span><span class="value">${this.escapeHtml(settlement.seller_name)}</span></div>
          <div class="detail-row"><span class="label">Buyer:</span><span class="value">${this.escapeHtml(settlement.buyer_name)}</span></div>
          <div class="detail-row"><span class="label">Amount:</span><span class="value">${this.formatCurrency(settlement.amount_cents)}</span></div>
        </div>
        <div class="settlement-steps">${this.renderSettlementSteps(settlement.status)}</div>
        <div class="settlement-info"><span class="text-muted">Last updated: ${this.timeAgo(settlement.updated_at)}</span></div>
      </div>
    `).join('');
  },

  updateAuctions(data) {
    const auctions = data.auctions || [];
    const container = document.getElementById('auctions-list');
    if (!container) return;
    if (auctions.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>🔨 No active auctions</p></div>';
      return;
    }
    container.innerHTML = auctions.map(auction => `
      <tr>
        <td><strong>${this.escapeHtml(auction.title)}</strong></td>
        <td>${this.escapeHtml(auction.seller_name)}</td>
        <td><span class="badge badge-secondary">${this.escapeHtml(auction.category)}</span></td>
        <td>${this.formatCurrency(auction.starting_price_cents)}</td>
        <td>${this.formatCurrency(auction.current_bid_cents)}</td>
        <td>${auction.bid_count}</td>
        <td><span class="badge ${auction.status === 'live' ? 'badge-success' : 'badge-secondary'}">${auction.status}</span></td>
        <td>${this.timeAgo(auction.ends_at)}</td>
      </tr>
    `).join('');
  },

  updateSellers(data) {
    const sellers = data.sellers || [];
    const container = document.getElementById('sellers-list');
    if (!container) return;
    if (sellers.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>🏆 No seller data available</p></div>';
      return;
    }
    container.innerHTML = sellers.map((seller, index) => `
      <tr>
        <td>${index + 1}</td>
        <td><strong>${this.escapeHtml(seller.seller_name)}</strong></td>
        <td>${this.formatNumber(seller.total_listed)}</td>
        <td>${this.formatNumber(seller.total_approved)}</td>
        <td>${this.formatCurrency(seller.total_revenue)}</td>
        <td>${this.formatNumber(seller.total_bids)}</td>
      </tr>
    `).join('');
  },

  updateMyListings(data) {
    const listings = data.listings || [];
    const container = document.getElementById('listings-list');
    if (!container) return;
    if (listings.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>📋 No listings found</p></div>';
      return;
    }
    container.innerHTML = listings.map(product => `
      <tr>
        <td>
          <div class="font-medium">${this.escapeHtml(product.title)}</div>
          ${product.description ? `<div class="text-muted" style="font-size: 0.8125rem;">${this.escapeHtml(product.description.length > 60 ? product.description.substring(0, 60) + '...' : product.description)}</div>` : ''}
        </td>
        <td><span class="badge badge-secondary">${this.escapeHtml(product.category)}</span></td>
        <td class="font-medium">${this.formatCurrency(product.price_cents)}</td>
        <td><span class="badge ${this.statusBadgeClass(product.status)}">${product.status.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())}</span></td>
        <td class="text-muted">${this.timeAgo(product.created_at)}</td>
      </tr>
    `).join('');
  },

  updateMyRevenue(data) {
    const revenue = data.revenue;
    if (!revenue) return;
    this.updateElement('stat-revenue-total', this.formatCurrency(revenue.total_revenue_cents || 0));
    this.updateElement('stat-listed', this.formatNumber(revenue.total_listed || 0));
    this.updateElement('stat-approved', this.formatNumber(revenue.total_approved || 0));
    this.updateElement('stat-rejected', this.formatNumber(revenue.total_rejected || 0));
    this.updateElement('stat-auctions-started', this.formatNumber(revenue.total_auctions_started || 0));
    this.updateElement('stat-bids-received', this.formatNumber(revenue.total_bids_received || 0));
  },

  updateMyBids(data) {
    const bids = data.bids || [];
    const container = document.getElementById('bids-list');
    if (!container) return;
    if (bids.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>🔨 No bid activity found</p></div>';
      return;
    }
    container.innerHTML = bids.map(bid => `
      <tr>
        <td><div class="font-medium">${this.escapeHtml(bid.product_title)}</div></td>
        <td>${this.escapeHtml(bid.seller_name)}</td>
        <td class="font-semibold">${this.formatCurrency(bid.amount_cents)}</td>
        <td><span class="badge ${this.statusBadgeClass(bid.status)}">${bid.status.charAt(0).toUpperCase() + bid.status.slice(1)}</span></td>
        <td class="text-muted">${this.timeAgo(bid.created_at)}</td>
      </tr>
    `).join('');
  },

  updateMyWon(data) {
    const won = data.won || [];
    const container = document.getElementById('won-list');
    if (!container) return;
    if (won.length === 0) {
      container.innerHTML = '<div class="empty-state"><p>🏆 No won auctions yet</p></div>';
      return;
    }
    container.innerHTML = won.map(win => `
      <tr>
        <td><div class="font-medium">${this.escapeHtml(win.product_title)}</div></td>
        <td>${this.escapeHtml(win.seller_name)}</td>
        <td class="font-semibold">${this.formatCurrency(win.amount_cents)}</td>
        <td class="text-muted">${this.timeAgo(win.updated_at)}</td>
      </tr>
    `).join('');
  },

  // === UTILITY FUNCTIONS ===

  renderSettlementSteps(currentStatus) {
    const steps = ['invoiced', 'paid', 'shipped', 'completed'];
    const currentIndex = steps.indexOf(currentStatus);
    return steps.map((step, idx) => {
      const isCompleted = idx <= currentIndex;
      return `<span class="step ${isCompleted ? 'completed' : ''}">${step}</span>`;
    }).join('');
  },

  statusBadgeClass(status) {
    const classes = {
      'pending_approval': 'badge-warning', 'draft': 'badge-success', 'approved': 'badge-success',
      'rejected': 'badge-danger', 'live': 'badge-info', 'ended': 'badge-secondary',
      'completed': 'badge-primary', 'invoiced': 'badge-warning', 'paid': 'badge-info', 'shipped': 'badge-success'
    };
    return classes[status] || 'badge-secondary';
  },

  updateElement(id, value) {
    const element = document.getElementById(id);
    if (element) {
      element.textContent = value;
      element.classList.add('pulse');
      setTimeout(() => element.classList.remove('pulse'), 500);
    }
  },

  showLastUpdated() {
    const element = document.getElementById('last-updated');
    if (element) {
      element.textContent = `Last updated: ${new Date().toLocaleTimeString()}`;
    }
  },

  formatNumber(num) {
    return new Intl.NumberFormat().format(num);
  },

  formatCurrency(cents) {
    return '$' + (cents / 100).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  },

  timeAgo(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const now = new Date();
    const diff = (now - date) / 1000;
    if (diff < 60) return 'just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
  },

  escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  },

  getUrlParam(name) {
    return new URLSearchParams(window.location.search).get(name);
  },

  // === RECONNECTION ===

  scheduleReconnect() {
    if (this.state.reconnectTimer) return;
    const delay = Math.min(
      this.config.reconnectBaseDelay * Math.pow(2, this.state.reconnectAttempts),
      this.config.reconnectMaxDelay
    );
    console.log(`🔄 Reconnecting in ${delay}ms (attempt ${this.state.reconnectAttempts + 1})`);
    this.state.reconnectTimer = setTimeout(() => {
      this.state.reconnectTimer = null;
      this.state.reconnectAttempts++;
      this.connect();
    }, delay);
  },

  // === HEARTBEAT MONITOR ===

  startHeartbeatMonitor() {
    clearInterval(this.state.heartbeatTimer);
    this.state.heartbeatTimer = setInterval(() => {
      // Refresh tab registration (proves this tab is still alive)
      this._registerTab();

      // If not the leader anymore, close SSE to free the thread
      if (!this._isLeader()) {
        console.log('⏸️ Lost SSE leadership to newer tab, closing connection');
        this.disconnect();
        this.updateConnectionStatus('disconnected');
        return;
      }

      // Only force-reconnect if the EventSource is actually closed/given up
      const readyState = this.state.eventSource?.readyState;
      if (readyState === EventSource.CLOSED) {
        console.warn('⚠️ SSE connection closed, forcing reconnect...');
        this.state.reconnectAttempts = 0;
        this.connect();
      }
    }, this.config.heartbeatTimeout / 2);
  },

  // === UI HELPERS ===

  updateConnectionStatus(status) {
    const indicator = document.getElementById('connection-status');
    if (indicator) {
      indicator.className = `connection-status ${status}`;
      indicator.title = status === 'connected' ? 'Real-time updates active' : 'Disconnected - reconnecting...';
    }
  },

  showEventNotification(eventType) {
    // Brief visual flash on the page to indicate a real-time update arrived
    document.body.classList.add('sse-flash');
    setTimeout(() => document.body.classList.remove('sse-flash'), 300);
  },

  // === PAGE DETECTION ===

  getCurrentPage() {
    const path = window.location.pathname;
    if (path === '/admin' || path === '/admin/') return 'overview';
    if (path.includes('/approval')) return 'approval';
    if (path.includes('/settlements')) return 'settlements';
    if (path.includes('/auctions')) return 'auctions';
    if (path.includes('/sellers')) return 'sellers';
    if (path.includes('/my-listings')) return 'myListings';
    if (path.includes('/my-revenue')) return 'myRevenue';
    if (path.includes('/my-bids')) return 'myBids';
    if (path.includes('/my-won')) return 'myWon';
    return null;
  }
};

// Auto-initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  const page = SSEService.getCurrentPage();
  if (page) {
    SSEService.init(page);
  }
});

if (typeof module !== 'undefined' && module.exports) {
  module.exports = SSEService;
}
