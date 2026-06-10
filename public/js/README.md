# Polling Service

Auto-refreshing dashboard data for the Reporting Service admin panel.

## Features

- ⏱️ Configurable polling intervals (5s, 10s, 30s, 1min)
- ⏸️ Auto-pause when browser tab is hidden
- 🔄 Automatic error recovery
- 📊 Real-time data updates
- 🎨 Visual feedback on updates
- ⚠️ Error display with retry button

## Usage

The polling service is automatically loaded on all admin pages. It will:

1. Poll the API endpoints at the configured interval
2. Update the DOM with new data
3. Show "Last updated" timestamp
4. Pause when the tab is hidden
5. Resume when the tab is visible
6. Show error state after 2 consecutive failures

## Configuration

### Polling Interval

Use the dropdown selector on each page to change the polling interval:

- 5 seconds
- 10 seconds (default)
- 30 seconds
- 1 minute

### Programmatic Control

```javascript
// Set custom interval
PollingService.setInterval(5000); // 5 seconds

// Pause polling
PollingService.pause();

// Resume polling
PollingService.resume();

// Stop all polling
PollingService.stopAll();
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/api/reports/overview` | Platform metrics |
| `/api/reports/approval-queue` | Pending products |
| `/api/reports/settlements` | Settlement pipeline |
| `/api/reports/active-auctions` | Active auctions |
| `/api/reports/sellers` | Seller leaderboard |
| `/api/reports/bid-activity` | Bid analytics |
| `/api/reports/my-listings?seller_id=xxx` | Seller's listings |
| `/api/reports/my-revenue?seller_id=xxx` | Seller's revenue |
| `/api/reports/my-bids?buyer_id=xxx` | Buyer's bids |
| `/api/reports/my-won?buyer_id=xxx` | Buyer's won auctions |

## Pages with Polling

| Page | Endpoint |
|------|----------|
| `/admin` | Overview dashboard |
| `/admin/approval` | Approval queue |
| `/admin/settlements` | Settlement pipeline |
| `/admin/auctions` | Active auctions |
| `/admin/sellers` | Seller leaderboard |
| `/admin/my-listings` | Seller's listings |
| `/admin/my-revenue` | Seller's revenue |
| `/admin/my-bids` | Buyer's bids |
| `/admin/my-won` | Buyer's won auctions |

## Error Handling

- Retries automatically on network errors
- Stops polling after 5 consecutive errors
- Shows error state in UI with retry button
- Logs errors to console

## Browser Support

- Chrome 60+
- Firefox 55+
- Safari 11+
- Edge 79+

## Files

- `polling.js` - Main polling service
- `../css/style.css` - Polling UI styles
