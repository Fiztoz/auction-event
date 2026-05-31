require_relative "../../identity"

module Basic4::Identity::Infrastructure::StdoutNotifier
  def self.email_verification_token(email, token, io: $stdout)
    io.puts "[basic4] verification token for #{email}: #{token}"
    io.flush
  end

  def self.password_reset_token(email, token, io: $stdout)
    io.puts "[basic4] password reset token for #{email}: #{token}"
    io.flush
  end
end
