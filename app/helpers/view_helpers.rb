# frozen_string_literal: true

module ViewHelpers
  def format_currency(cents)
    "$#{'%.2f' % (cents.to_f / 100)}"
  end

  def format_date(date_str)
    return '' unless date_str
    Time.parse(date_str.to_s).strftime('%b %d, %Y')
  end

  def time_ago(date_str)
    return '' unless date_str
    diff = Time.now - Time.parse(date_str.to_s)
    case diff
    when 0..60 then 'just now'
    when 61..3600 then "#{(diff / 60).to_i}m ago"
    when 3601..86400 then "#{(diff / 3600).to_i}h ago"
    else "#{(diff / 86400).to_i}d ago"
    end
  end

  def status_badge_class(status)
    case status
    when 'pending_approval' then 'badge-warning'
    when 'draft', 'approved' then 'badge-success'
    when 'rejected' then 'badge-danger'
    when 'live' then 'badge-info'
    when 'ended' then 'badge-secondary'
    when 'completed' then 'badge-primary'
    when 'invoiced' then 'badge-warning'
    when 'paid' then 'badge-info'
    when 'shipped' then 'badge-success'
    else 'badge-secondary'
    end
  end
end