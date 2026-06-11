# frozen_string_literal: true

# Puma config for Reporting Service
# SSE streams hold threads for their lifetime, so we need enough threads
# to handle SSE connections + page requests simultaneously.

# Increase threads beyond default 5 to accommodate SSE streams
max_threads_count = ENV.fetch('PUMA_MAX_THREADS', 20)
min_threads_count = ENV.fetch('PUMA_MIN_THREADS', 5)
threads min_threads_count, max_threads_count

# Single worker (stateless service with DB-backed state)
workers 0

# Bind
port ENV.fetch('PORT', 4567)
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 4567)}"

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart
