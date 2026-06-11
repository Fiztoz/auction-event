# frozen_string_literal: true

require 'mysql2'

module Database
  # Thread-local MySQL connections — each Puma thread gets its own client.
  # This avoids "connection is in use" errors when multiple threads
  # try to query simultaneously.

  def self.client
    Thread.current[:db_client] ||= create_client
  end

  def self.create_client
    Mysql2::Client.new(
      host: ENV.fetch('MARIADB_HOST', 'localhost'),
      port: ENV.fetch('MARIADB_PORT', '3306').to_i,
      username: ENV.fetch('MARIADB_USER', 'root'),
      password: ENV.fetch('MARIADB_PASSWORD', ''),
      database: ENV.fetch('MARIADB_DATABASE', 'reporting'),
      connect_timeout: 10,
      read_timeout: 10,
      write_timeout: 10,
      reconnect: true,
      symbolize_keys: true
    )
  end

  def self.reset!
    if (c = Thread.current[:db_client])
      c.close rescue nil
    end
    Thread.current[:db_client] = nil
  end

  def self.execute(sql, params = [])
    if params.nil? || params.empty?
      client.query(sql)
    else
      stmt = client.prepare(sql)
      begin
        result = stmt.execute(*params)
        # Materialize the result before closing the statement
        # Mysql2::Result is lazy and may fail if statement is closed too early
        rows = result.to_a
        rows
      ensure
        stmt.close
      end
    end
  end

  def self.ping
    client.ping
  rescue StandardError
    false
  end

  def self.escape(value)
    client.escape(value.to_s)
  end
end
