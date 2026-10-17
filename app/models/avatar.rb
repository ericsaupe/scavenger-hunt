# frozen_string_literal: true

class Avatar < ApplicationRecord
  STYLES = {"team" => "critters", "person" => "thumbs"}.freeze
  KINDS = STYLES.keys.freeze
  ENDPOINT = "https://api.dicebear.com/10.x"
  TIMEOUT = 5
  MAX_BYTES = 256.kilobytes
  FAILURE_TTL = 1.minute
  ANIMATION_VARIANT = "medium"
  DIGEST_BODY_LENGTH = 48

  validates :kind, inclusion: {in: KINDS}
  validates :digest, format: /\A\h{64}\z/, uniqueness: {scope: :kind}
  validates :svg, presence: true

  def self.for(kind, seed, initial: nil)
    kind = kind.to_s
    raise ArgumentError, "unknown avatar kind #{kind.inspect}" unless KINDS.include?(kind)

    path = "/avatars/#{kind}/#{digest(kind, seed)}.svg"
    initial.present? ? "#{path}?#{{initial: initial.first.upcase}.to_query}" : path
  end

  def self.digest(kind, seed)
    body = hmac("#{kind}:#{seed}").first(DIGEST_BODY_LENGTH)
    body + digest_tag(kind, body)
  end

  def self.valid_digest?(kind, digest)
    digest = digest.to_s
    return false unless digest.match?(/\A\h{64}\z/)

    body = digest.first(DIGEST_BODY_LENGTH)
    ActiveSupport::SecurityUtils.secure_compare(digest, body + digest_tag(kind, body))
  end

  def self.digest_tag(kind, body)
    hmac("tag:#{kind}:#{body}").first(64 - DIGEST_BODY_LENGTH)
  end

  def self.hmac(message)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("avatars"), message)
  end

  def self.lookup(kind, digest)
    return unless valid_digest?(kind, digest)

    find_by(kind:, digest:) || fetch(kind, digest)
  end

  def self.timing(digest)
    {delay: ((digest.first(2).hex % 100) / 10.0).round(1), speed: (0.85 + (digest[2, 2].hex % 41) / 100.0).round(2)}
  end

  def self.desynchronize(svg, digest)
    prefix = svg[/--(db[a-z]+)-t/, 1]
    return svg unless prefix

    id = "av#{digest.first(10)}"
    timing = timing(digest)
    style = "<style>##{id}{--#{prefix}-t:#{timing[:speed]}}##{id} [class*='#{prefix}-']{animation-delay:-#{timing[:delay]}s}</style>"
    svg.sub(/<svg\b/, %(<svg id="#{id}")).sub(%r{</svg>\s*\z}, "#{style}</svg>")
  end

  def self.fetch(kind, digest)
    failure_key = "avatars/#{kind}/#{digest}/failed"
    return if Rails.cache.exist?(failure_key)

    svg = download(kind, digest)
    if svg.nil?
      Rails.cache.write(failure_key, true, expires_in: FAILURE_TTL)
      return
    end

    create!(kind:, digest:, svg: desynchronize(svg, digest))
  rescue ActiveRecord::RecordNotUnique
    find_by!(kind:, digest:)
  end

  def self.dicebear_uri(kind, seed)
    URI("#{ENDPOINT}/#{STYLES.fetch(kind)}/svg").tap do |uri|
      uri.query = URI.encode_www_form(seed:, animationVariant: ANIMATION_VARIANT)
    end
  end

  def self.download(kind, seed)
    uri = dicebear_uri(kind, seed)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri, "Accept" => "image/svg+xml", "User-Agent" => "Scavenger Hunt Party avatars")
    end
    unless response.is_a?(Net::HTTPSuccess) && response.content_type == "image/svg+xml"
      Rails.logger.warn("Avatar fetch failed for #{kind} #{seed}: HTTP #{response.code} #{response.content_type}")
      return
    end

    body = response.body.to_s
    body if body.bytesize <= MAX_BYTES && valid_svg?(body)
  rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError => error
    Rails.logger.warn("Avatar fetch failed for #{kind} #{seed}: #{error.class}: #{error.message}")
    nil
  end

  def self.valid_svg?(body)
    document = Nokogiri::XML(body) { |config| config.strict.nonet }
    document.root&.name == "svg" && document.xpath("//*[local-name()='script' or local-name()='foreignObject']").empty?
  rescue Nokogiri::XML::SyntaxError
    false
  end
end
