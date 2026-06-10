/**
 * Polling Service for Admin Dashboard
 * Automatically refreshes dashboard data at configurable intervals
 * with loading states, error handling, and retry logic.
 */

const PollingService = {
  // Configuration
  config: {
    interval: 10000, // 10 seconds default
    enabled: true,
    maxRetries: 3,
    retryDelay: 2000,
    endpoints: {
      overview: '/api/reports/overview',
      approvalQueue: '/api/reports/approval-queue',
      settlements: '/api/reports/settlements',
      activeAuctions: '/api/reports/active-auctions',
      sellers: '/api/reports/sellers',
      bidActivity: '/api/reports/bid-activity',
      myListings: '/api/reports/my-listings',
      myRevenue: '/api/reports/my-revenue',
      myBids: '/api/reports/my-bids',
      myWon: '/api/reports/my-won'
    }
  },

  // State
  state: {
    timers: {},
    lastUpdate: {},
    isPaused: false,
    errorCount: {},
    retryAttempts: {}
  },

  /**
   * Initialize polling for a specific page
   * @param {string} page - Page name
   */
  init(page) {
    console.log(`🔄 Initializing polling for: ${page}`);
    
    switch (page) {
      case 'overview':
        this.startOverviewPolling();
        break;
      case 'approval':
        this.startApprovalPolling();
        break;
      case 'settlements':
        this.startSettlementsPolling();
        break;
      case 'auctions':
        this.startAuctionsPolling();
        break;
      case 'sellers':
        this.startSellersPolling();
        break;
      case 'myListings':
        this.startMyListingsPolling();
        break;
      case 'myRevenue':
        this.startMyRevenuePolling();
        break;
      case 'myBids':
        this.startMyBidsPolling();
        break;
      case 'myWon':
        this.startMyWonPolling();
        break;
      default:
        console.log(`No polling configured for page: ${page}`);
    }

    // Add visibility change listener to pause/resume
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        this.pause();
      } else {
        this.resume();
      }
    });
  },

  /**
   * Show loading spinner
   */
  showLoading(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;
    // Don't show spinner if container is an empty state
    if (container.querySelector('.empty-state')) return;
    
    const spinner = document.createElement('div');
    spinner.className = 'loading-overlay';
    spinner.id = `loading-${containerId}`;
    spinner.innerHTML = '<div class="loading-spinner"></div>';
    container.style.position = 'relative';
    container.appendChild(spinner);
  },

  /**
   * Hide loading spinner
   */
  hideLoading(containerId) {
    const spinner = document.getElementById(`loading-${containerId}`);
    if (spinner) {
      spinner.remove();
    }
  },

  /**
   * Show error message
   */
  showError(containerId, message) {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    // Remove existing error
    this.hideError(containerId);
    
    const errorEl = document.createElement('div');
    errorEl.className = 'polling-error';
    errorEl.id = `error-${containerId}`;
    errorEl.innerHTML = `
      <div class="polling-error-content">
        <span class="polling-error-icon">⚠️</span>
        <span class="polling-error-text">${this.escapeHtml(message)}</span>
        <button class="btn btn-sm btn-secondary poll-retry-btn" onclick="PollingService.retry('${containerId}')">Retry</button>
      </div>
    `;
    container.parentNode.insertBefore(errorEl, container);
  },

  /**
   * Hide error message
   */
  hideError(containerId) {
    const error = document.getElementById(`error-${containerId}`);
    if (error) {
      error.remove();
    }
  },

  /**
   * Retry a failed fetch
   */
  retry(containerId) {
    this.hideError(containerId);
    this.state.retryAttempts[containerId] = 0;
    this.state.errorCount[containerId] = 0;
  },

  /**
   * Start polling for overview dashboard
   */
  startOverviewPolling() {
    this.state.timers.overview = setInterval(() => {
      if (!this.state.isPaused) {
        this.fetchAndUpdate('overview', this.updateOverview.bind(this));
      }
    }, this.config.interval);
  },

  /**
   * Start polling for approval queue
   */
  startApprovalPolling() {
    this.state.timers.approval = setInterval(() => {
      if (!this.state.isPaused) {
        this.fetchAndUpdate('approvalQueue', this.updateApprovalQueue.bind(this));
      }
    }, this.config.interval);
  },

  /**
   * Start polling for settlements
   */
  startSettlementsPolling() {
    this.state.timers.settlements = setInterval(() => {
      if (!this.state.isPaused) {
        this.fetchAndUpdate('settlements', this.updateSettlements.bind(this));
      }
    }, this.config.interval);
  },

  /**
   * Start polling for active auctions
   */
  startAuctionsPolling() {
    this.state.timers.auctions = setInterval(() => {
      if (!this.state.isPaused) {
        this.fetchAndUpdate('activeAuctions', this.updateAuctions.bind(this));
      }
    }, this.config.interval);
  },

  /**
   * Start polling for seller stats
   */
  startSellersPolling() {
    this.state.timers.sellers = setInterval(() => {
      if (!this.state.isPaused) {
        this.fetchAndUpdate('sellers', this.updateSellers.bind(this));
      }
    }, this.config.interval);
  },

  /**
   * Start polling for my listings
   */
  startMyListingsPolling() {
    this.state.timers.myListings = setInterval(() => {
      if (!this.state.isPaused) {
        const sellerId = this.getUrlParam('seller_id');
        if (sellerId) {
          this.fetchAndUpdateWithParams('myListings', { seller_id: sellerId }, this.updateMyListings.bind(this));
        }
      }
    }, this.config.interval);
  },

  /**
   * Start polling for my revenue
   */
  startMyRevenuePolling() {
    this.state.timers.myRevenue = setInterval(() => {
      if (!this.state.isPaused) {
        const sellerId = this.getUrlParam('seller_id');
        if (sellerId) {
          this.fetchAndUpdateWithParams('myRevenue', { seller_id: sellerId }, this.updateMyRevenue.bind(this));
        }
      }
    }, this.config.interval);
  },

  /**
   * Start polling for my bids
   */
  startMyBidsPolling() {
    this.state.timers.myBids = setInterval(() => {
      if (!this.state.isPaused) {
        const buyerId = this.getUrlParam('buyer_id');
        if (buyerId) {
          this.fetchAndUpdateWithParams('myBids', { buyer_id: buyerId }, this.updateMyBids.bind(this));
        }
      }
    }, this.config.interval);
  },

  /**
   * Start polling for my won auctions
   */
  startMyWonPolling() {
    this.state.timers.myWon = setInterval(() => {
      if (!this.state.isPaused) {
        const buyerId = this.getUrlParam('buyer_id');
        if (buyerId) {
          this.fetchAndUpdateWithParams('myWon', { buyer_id: buyerId }, this.updateMyWon.bind(this));
        }
      }
    }, this.config.interval);
  },

  /**
   * Get URL query parameter
   */
  getUrlParam(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
  },

  /**
   * Fetch data from endpoint and call update function
   */
  async fetchAndUpdate(endpoint, updateFn) {
    try {
      const url = this.config.endpoints[endpoint];
      const containerId = this.getContainerId(endpoint);
      
      this.showLoading(containerId);
      
      const response = await fetch(url);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      this.state.lastUpdate[endpoint] = new Date();
      this.state.errorCount[endpoint] = 0;
      this.state.retryAttempts[endpoint] = 0;
      
      this.hideLoading(containerId);
      this.hideError(containerId);
      
      updateFn(data);
      this.showLastUpdated(endpoint);
      
    } catch (error) {
      console.error(`Polling error for ${endpoint}:`, error);
      this.state.errorCount[endpoint] = (this.state.errorCount[endpoint] || 0) + 1;
      
      const containerId = this.getContainerId(endpoint);
      this.hideLoading(containerId);
      
      // Show error after 2 consecutive failures
      if (this.state.errorCount[endpoint] >= 2) {
        this.showError(containerId, `Failed to load data (${error.message})`);
      }
      
      // Stop polling after 5 consecutive errors
      if (this.state.errorCount[endpoint] >= 5) {
        console.warn(`Stopping polling for ${endpoint} after 5 errors`);
        this.stop(endpoint);
      }
    }
  },

  /**
   * Fetch data with query parameters
   */
  async fetchAndUpdateWithParams(endpoint, params, updateFn) {
    try {
      const url = new URL(this.config.endpoints[endpoint], window.location.origin);
      Object.keys(params).forEach(key => url.searchParams.set(key, params[key]));
      
      const containerId = this.getContainerId(endpoint);
      
      this.showLoading(containerId);
      
      const response = await fetch(url.toString());
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      this.state.lastUpdate[endpoint] = new Date();
      this.state.errorCount[endpoint] = 0;
      this.state.retryAttempts[endpoint] = 0;
      
      this.hideLoading(containerId);
      this.hideError(containerId);
      
      updateFn(data);
      this.showLastUpdated(endpoint);
      
    } catch (error) {
      console.error(`Polling error for ${endpoint}:`, error);
      this.state.errorCount[endpoint] = (this.state.errorCount[endpoint] || 0) + 1;
      
      const containerId = this.getContainerId(endpoint);
      this.hideLoading(containerId);
      
      if (this.state.errorCount[endpoint] >= 2) {
        this.showError(containerId, `Failed to load data (${error.message})`);
      }
      
      if (this.state.errorCount[endpoint] >= 5) {
        console.warn(`Stopping polling for ${endpoint} after 5 errors`);
        this.stop(endpoint);
      }
    }
  },

  /**
   * Get container element ID for an endpoint
   */
  getContainerId(endpoint) {
    const map = {
      overview: 'stat-users',
      approvalQueue: 'approval-list',
      settlements: 'settlements-list',
      activeAuctions: 'auctions-list',
      sellers: 'sellers-list',
      myListings: 'listings-list',
      myRevenue: 'stat-revenue-total',
      myBids: 'bids-list',
      myWon: 'won-list'
    };
    return map[endpoint] || null;
  },

  /**
   * Update overview dashboard
   */
  updateOverview(data) {
    const overview = data.overview;
    if (!overview || !Array.isArray(overview) || overview.length === 0) return;
    
    const metrics = overview[0]; // Latest day
    
    // Update stat cards
    this.updateElement('stat-users', this.formatNumber(metrics.total_users || 0));
    this.updateElement('stat-auctions', this.formatNumber(metrics.active_auctions || 0));
    this.updateElement('stat-revenue', this.formatCurrency(metrics.total_revenue_cents || 0));
    this.updateElement('stat-bids', this.formatNumber(metrics.total_bids || 0));
    this.updateElement('stat-new-users', this.formatNumber(metrics.new_users || 0));
    this.updateElement('stat-settlements', this.formatNumber(metrics.settlements_completed || 0));
  },

  /**
   * Update approval queue
   */
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
    
    // Update count badge
    this.updateElement('pending-count', products.length);
  },

  /**
   * Update settlements
   */
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
          <div class="detail-row">
            <span class="label">Seller:</span>
            <span class="value">${this.escapeHtml(settlement.seller_name)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Buyer:</span>
            <span class="value">${this.escapeHtml(settlement.buyer_name)}</span>
          </div>
          <div class="detail-row">
            <span class="label">Amount:</span>
            <span class="value">${this.formatCurrency(settlement.amount_cents)}</span>
          </div>
        </div>
        <div class="settlement-steps">
          ${this.renderSettlementSteps(settlement.status)}
        </div>
        <div class="settlement-info">
          <span class="text-muted">Last updated: ${this.timeAgo(settlement.updated_at)}</span>
        </div>
      </div>
    `).join('');
  },

  /**
   * Update active auctions
   */
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

  /**
   * Update seller stats
   */
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

  /**
   * Update my listings
   */
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

  /**
   * Update my revenue stats
   */
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

  /**
   * Update my bids
   */
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

  /**
   * Update my won auctions
   */
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

  /**
   * Render settlement progress steps
   */
  renderSettlementSteps(currentStatus) {
    const steps = ['invoiced', 'paid', 'shipped', 'completed'];
    const currentIndex = steps.indexOf(currentStatus);
    
    return steps.map((step, idx) => {
      const isCompleted = idx <= currentIndex;
      return `<span class="step ${isCompleted ? 'completed' : ''}">${step}</span>`;
    }).join('');
  },

  /**
   * Get status badge class
   */
  statusBadgeClass(status) {
    const classes = {
      'pending_approval': 'badge-warning',
      'draft': 'badge-success',
      'approved': 'badge-success',
      'rejected': 'badge-danger',
      'live': 'badge-info',
      'ended': 'badge-secondary',
      'completed': 'badge-primary',
      'invoiced': 'badge-warning',
      'paid': 'badge-info',
      'shipped': 'badge-success'
    };
    return classes[status] || 'badge-secondary';
  },

  /**
   * Update element content
   */
  updateElement(id, value) {
    const element = document.getElementById(id);
    if (element) {
      element.textContent = value;
      element.classList.add('pulse');
      setTimeout(() => element.classList.remove('pulse'), 500);
    }
  },

  /**
   * Show last updated timestamp
   */
  showLastUpdated(endpoint) {
    const element = document.getElementById('last-updated');
    if (element) {
      element.textContent = `Last updated: ${new Date().toLocaleTimeString()}`;
    }
  },

  /**
   * Format number with commas
   */
  formatNumber(num) {
    return new Intl.NumberFormat().format(num);
  },

  /**
   * Format currency
   */
  formatCurrency(cents) {
    return '$' + (cents / 100).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  },

  /**
   * Time ago formatting
   */
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

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  },

  /**
   * Pause all polling
   */
  pause() {
    this.state.isPaused = true;
    console.log('⏸️ Polling paused');
  },

  /**
   * Resume all polling
   */
  resume() {
    this.state.isPaused = false;
    console.log('▶️ Polling resumed');
  },

  /**
   * Stop polling for a specific endpoint
   */
  stop(endpoint) {
    if (this.state.timers[endpoint]) {
      clearInterval(this.state.timers[endpoint]);
      delete this.state.timers[endpoint];
      console.log(`⏹️ Stopped polling for: ${endpoint}`);
    }
  },

  /**
   * Stop all polling
   */
  stopAll() {
    Object.keys(this.state.timers).forEach(endpoint => {
      this.stop(endpoint);
    });
    console.log('⏹️ All polling stopped');
  },

  /**
   * Set polling interval
   */
  setInterval(ms) {
    this.config.interval = ms;
    console.log(`⏱️ Polling interval set to: ${ms}ms`);
    
    // Restart all timers with new interval
    const currentPage = this.getCurrentPage();
    if (currentPage) {
      this.stopAll();
      this.init(currentPage);
    }
  },

  /**
   * Get current page from URL
   */
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
  const page = PollingService.getCurrentPage();
  if (page) {
    PollingService.init(page);
  }
});

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = PollingService;
}
