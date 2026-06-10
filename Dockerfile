FROM ruby:3.2-slim

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    default-libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile ./
RUN bundle install

# Copy application code
COPY . .

# Expose port
EXPOSE 4567

# Start the application
CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "4567"]
