# frozen_string_literal: true

require 'sinatra/base'
require_relative '../models/report'
require_relative '../helpers/view_helpers'

class ReportsController < Sinatra::Base
  set :views, File.join(File.dirname(__FILE__), '..', 'views')
  helpers ViewHelpers

  # All browse/dashboard routes removed - consolidated under /admin
end
