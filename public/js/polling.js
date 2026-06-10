/**
 * Polling Service for Admin Dashboard
 * Automatically refreshes dashboard data at configurable intervals
 */

const PollingService = {
  // Configuration
  config: {
    interval: 10000, // 10 seconds default
    enabled: true,
    endpoints: {
      overview: '/api/reports/overview',
      approvalQueue: '/api/reports/approval-queue',
      settlements: '/api/reports/settlements',
      activeAuctions: '/api/reports/active-auctions',
      sellers: '/api/reports/sellers',
      bidActivity: '/api/reports/bid-activity'
    }
  },

  // State
  state: {
    timers: {},
    lastUpdate: {},
    isPaused: false,
    errorCount: {}
  },

  /**
   * Initialize polling for a specific page
   * @param {string} page - Page name (overview, approval, settlements, auctions, sellers)
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
   * Fetch data from endpoint and call update function
   */
  async fetchAndUpdate(endpoint, updateFn) {
    try {
      const url = this.config.endpoints[endpoint];
      const response = await fetch(url);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      this.state.lastUpdate[endpoint] = new Date();
      this.state.errorCount[endpoint] = 0;
      
      updateFn(data);
      this.showLastUpdated(endpoint);
      
    } catch (error) {
      console.error(`Polling error for ${endpoint}:`, error);
      this.state.errorCount[endpoint] = (this.state.errorCount[endpoint] || 0) + 1;
      
      // Stop polling after 5 consecutive errors
      if (this.state.errorCount[endpoint] >= 5) {
        console.warn(`Stopping polling for ${endpoint} after 5 errors`);
        this.stop(endpoint);
      }
    }
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
