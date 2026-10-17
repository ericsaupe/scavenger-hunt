# frozen_string_literal: true

require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

module AvatarHelpers
  DICEBEAR = %r{\Ahttps://api\.dicebear\.com/10\.x/(critters|thumbs)/svg}

  def stub_dicebear(body: Rails.root.join("spec/fixtures/avatar.svg").read, status: 200, content_type: "image/svg+xml")
    stub_request(:get, DICEBEAR).to_return(status:, body:, headers: {"Content-Type" => content_type})
  end
end

RSpec.configure do |config|
  config.include AvatarHelpers

  config.before { stub_dicebear }
end
