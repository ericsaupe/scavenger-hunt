# frozen_string_literal: true

unless Rails.env.production?
  require 'byebug/core'
  Byebug.start_server 'localhost', 8989
end
