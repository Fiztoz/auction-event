#!/bin/bash
# Run all mock event scripts

echo "🚀 Running all mock event scripts..."
echo

# Run selling events
echo "=== Selling Service ==="
docker compose exec -T app ruby bin/mock_events/selling.rb

echo
echo "=== Bidding Service ==="
docker compose exec -T app ruby bin/mock_events/bidding.rb

echo
echo "=== Settlement Service ==="
docker compose exec -T app ruby bin/mock_events/settlement.rb

echo
echo "=== Onboarding Service ==="
docker compose exec -T app ruby bin/mock_events/onboarding.rb

echo
echo "✅ All mock events completed!"
