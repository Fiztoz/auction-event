#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mysql2'
require 'securerandom'
require 'date'

# Wait for MariaDB to be ready
puts "Waiting for MariaDB..."
sleep 5

client = Mysql2::Client.new(
  host: ENV.fetch('MARIADB_HOST', 'localhost'),
  port: ENV.fetch('MARIADB_PORT', '3306').to_i,
  username: ENV.fetch('MARIADB_USER', 'root'),
  password: ENV.fetch('MARIADB_PASSWORD', ''),
  database: ENV.fetch('MARIADB_DATABASE', 'reporting')
)

puts "🌱 Seeding demo data for Reporting Service..."

def random_uuid
  SecureRandom.uuid
end

def random_name
  %w[John Jane Bob Alice Charlie Diana Eve Frank Grace Henry].sample
end

def random_category
  %w[electronics collectibles fashion home toys other].sample
end

def random_status
  %w[completed completed completed ended live live pending_approval].sample
end

def random_settlement_status
  %w[invoiced paid shipped completed].sample
end

def random_int(min, max)
  rand(min..max)
end

# Seed Platform Daily Metrics
puts "📊 Seeding platform daily metrics..."
30.downto(0) do |i|
  date = Date.today - i
  total_users = 100 + (30 - i) * 5
  new_users = random_int(3, 12)
  total_sellers = 20 + (30 - i) * 2
  total_buyers = total_users - total_sellers
  # For today, we'll calculate active_auctions after seeding auctions
  # For historical dates, use random values
  if i == 0
    active_auctions = 0  # Will be updated after auctions are seeded
  else
    active_auctions = random_int(15, 45)
  end
  total_auctions_created = random_int(50, 150)
  total_bids = random_int(200, 800)
  total_revenue_cents = random_int(500000, 2000000)
  settlements_completed = random_int(10, 30)

  client.query(
    "INSERT INTO report_platform_daily 
    (report_date, total_users, new_users, total_sellers, total_buyers,
     active_auctions, total_auctions_created, total_bids, total_revenue_cents,
     settlements_completed, updated_at)
    VALUES 
    ('#{date}', #{total_users}, #{new_users}, #{total_sellers}, #{total_buyers},
     #{active_auctions}, #{total_auctions_created}, #{total_bids}, #{total_revenue_cents},
     #{settlements_completed}, NOW())
    ON DUPLICATE KEY UPDATE
    total_users = VALUES(total_users),
    new_users = VALUES(new_users),
    updated_at = NOW()"
  )
end
puts "  ✓ Platform daily metrics seeded"

# Seed Approval Queue
puts "📦 Seeding approval queue..."
5.times do
  product_id = random_uuid
  seller_id = random_uuid
  seller_name = random_name
  title = "Product #{random_int(1000, 9999)}"
  category = random_category
  price_cents = random_int(1000, 50000)
  created_at = (Time.now - random_int(1, 48) * 3600).strftime('%Y-%m-%d %H:%M:%S')

  client.query(
    "INSERT INTO report_approval_queue 
    (product_id, seller_id, seller_name, title, category, price_cents,
     status, created_at, updated_at)
    VALUES 
    ('#{product_id}', '#{seller_id}', '#{seller_name}', '#{title}',
     '#{category}', #{price_cents}, 'pending_approval', '#{created_at}', NOW())
    ON DUPLICATE KEY UPDATE updated_at = NOW()"
  )
end

3.times do
  product_id = random_uuid
  seller_id = random_uuid
  seller_name = random_name
  title = "Rejected Product #{random_int(1000, 9999)}"
  category = random_category
  price_cents = random_int(1000, 50000)
  rejection_reason = ['Description too vague', 'Price too high', 'Missing images'].sample
  created_at = (Time.now - random_int(24, 72) * 3600).strftime('%Y-%m-%d %H:%M:%S')

  client.query(
    "INSERT INTO report_approval_queue 
    (product_id, seller_id, seller_name, title, category, price_cents,
     status, rejection_reason, created_at, updated_at)
    VALUES 
    ('#{product_id}', '#{seller_id}', '#{seller_name}', '#{title}',
     '#{category}', #{price_cents}, 'rejected', '#{rejection_reason}',
     '#{created_at}', NOW())
    ON DUPLICATE KEY UPDATE updated_at = NOW()"
  )
end
puts "  ✓ Approval queue seeded"

# Seed Active Auctions
puts "🔨 Seeding active auctions..."
10.times do
  product_id = random_uuid
  seller_id = random_uuid
  seller_name = random_name
  title = "Auction #{random_int(1000, 9999)}"
  category = random_category
  starting_price_cents = random_int(1000, 25000)
  current_bid_cents = starting_price_cents + random_int(0, 10000)
  bid_count = random_int(0, 20)
  status = random_status
  started_at = (Time.now - random_int(1, 72) * 3600).strftime('%Y-%m-%d %H:%M:%S')
  ends_at = (Time.now + random_int(1, 7) * 86400).strftime('%Y-%m-%d %H:%M:%S')

  client.query(
    "INSERT INTO report_active_auctions 
    (product_id, seller_id, seller_name, title, category, starting_price_cents,
     current_bid_cents, bid_count, status, started_at, ends_at, updated_at)
    VALUES 
    ('#{product_id}', '#{seller_id}', '#{seller_name}', '#{title}', '#{category}',
     #{starting_price_cents}, #{current_bid_cents}, #{bid_count}, '#{status}',
     '#{started_at}', '#{ends_at}', NOW())
    ON DUPLICATE KEY UPDATE 
    current_bid_cents = VALUES(current_bid_cents),
    bid_count = VALUES(bid_count),
    updated_at = NOW()"
  )
end

# Update platform daily metrics with actual live auction count for today
live_auction_count = client.query("SELECT COUNT(*) as count FROM report_active_auctions WHERE status = 'live'").first[:count]
client.query("UPDATE report_platform_daily SET active_auctions = #{live_auction_count} WHERE report_date = CURDATE()")
puts "  ✓ Updated platform daily metrics with #{live_auction_count} live auctions"

puts "  ✓ Active auctions seeded"

# Seed Settlement Pipeline
puts "💰 Seeding settlement pipeline..."
8.times do
  settlement_id = random_uuid
  product_id = random_uuid
  product_title = "Settled Item #{random_int(1000, 9999)}"
  seller_id = random_uuid
  seller_name = random_name
  buyer_id = random_uuid
  buyer_name = random_name
  amount_cents = random_int(5000, 100000)
  status = random_settlement_status
  created_at = (Time.now - random_int(1, 30) * 86400).strftime('%Y-%m-%d %H:%M:%S')

  client.query(
    "INSERT INTO report_settlements 
    (settlement_id, product_id, product_title, seller_id, seller_name,
     buyer_id, buyer_name, amount_cents, status, created_at, updated_at)
    VALUES 
    ('#{settlement_id}', '#{product_id}', '#{product_title}', '#{seller_id}',
     '#{seller_name}', '#{buyer_id}', '#{buyer_name}', #{amount_cents},
     '#{status}', '#{created_at}', NOW())
    ON DUPLICATE KEY UPDATE updated_at = NOW()"
  )
end
puts "  ✓ Settlement pipeline seeded"

# Seed Seller Stats
puts "🏆 Seeding seller stats..."
seller_ids = 5.times.map { random_uuid }
seller_names = 5.times.map { random_name }

30.downto(0) do |i|
  date = Date.today - i
  seller_ids.each_with_index do |seller_id, idx|
    products_listed = random_int(0, 5)
    products_approved = random_int(0, products_listed)
    products_rejected = products_listed - products_approved
    auctions_started = random_int(0, 3)
    auctions_ended = random_int(0, auctions_started)
    revenue_cents = random_int(0, 50000)
    bids_received = random_int(0, 50)

    client.query(
      "INSERT INTO report_seller_stats 
      (seller_id, seller_name, period_date, products_listed, products_approved,
       products_rejected, auctions_started, auctions_ended, revenue_cents, bids_received)
      VALUES 
      ('#{seller_id}', '#{seller_names[idx]}', '#{date}', #{products_listed},
       #{products_approved}, #{products_rejected}, #{auctions_started},
       #{auctions_ended}, #{revenue_cents}, #{bids_received})
      ON DUPLICATE KEY UPDATE 
      products_listed = products_listed + VALUES(products_listed),
      revenue_cents = revenue_cents + VALUES(revenue_cents),
      bids_received = bids_received + VALUES(bids_received)"
    )
  end
end
puts "  ✓ Seller stats seeded"

# Seed Bid Activity
puts "📈 Seeding bid activity..."
30.downto(0) do |i|
  date = Date.today - i
  24.times do |hour|
    total_bids = random_int(0, 50)
    unique_bidders = random_int(0, [total_bids, 20].min)
    unique_products = random_int(0, [total_bids, 15].min)
    avg_bid_cents = random_int(1000, 25000)
    max_bid_cents = avg_bid_cents + random_int(0, 10000)

    client.query(
      "INSERT INTO report_bid_activity 
      (period_date, hour, total_bids, unique_bidders, unique_products,
       avg_bid_cents, max_bid_cents)
      VALUES 
      ('#{date}', #{hour}, #{total_bids}, #{unique_bidders}, #{unique_products},
       #{avg_bid_cents}, #{max_bid_cents})
      ON DUPLICATE KEY UPDATE 
      total_bids = total_bids + VALUES(total_bids),
      unique_bidders = unique_bidders + VALUES(unique_bidders)"
    )
  end
end
puts "  ✓ Bid activity seeded"

puts ""
puts "✅ Demo data seeding complete!"
puts "   - 31 days of platform metrics"
puts "   - 8 products in approval queue (5 pending, 3 rejected)"
puts "   - 10 active auctions"
puts "   - 8 settlements in pipeline"
puts "   - 5 sellers with 31 days of stats"
puts "   - 720 hours of bid activity"

client.close
