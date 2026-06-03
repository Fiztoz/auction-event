FROM jruby:10.0.5.0-jre

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    RACK_ENV=production \
    PORT=4567

# netbase provides /etc/protocols + /etc/services. Without it, JRuby's Mongo
# driver monitor thread fails getprotobyname("tcp") -> "getprotobyname_r failed".
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential netbase \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 4567

CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "4567"]
