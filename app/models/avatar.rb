# frozen_string_literal: true

class Avatar < ApplicationRecord
  STYLES = {"team" => "critters", "person" => "thumbs"}.freeze
  KINDS = STYLES.keys.freeze
  ENDPOINT = "https://api.dicebear.com/10.x"
  TIMEOUT = 5
  MAX_BYTES = 256.kilobytes
  FAILURE_TTL = 1.minute
  ANIMATION_VARIANTS = %w[fast medium slow].freeze

  validates :kind, inclusion: {in: KINDS}
  validates :digest, format: /\A\h{64}\z/, uniqueness: {scope: :kind}
  validates :svg, presence: true

  def self.for(kind, seed, initial: nil, still: false)
    kind = kind.to_s
    raise ArgumentError, "unknown avatar kind #{kind.inspect}" unless KINDS.include?(kind)

    query = {initial: initial.presence&.first&.upcase, still: ("1" if still)}.compact
    path = "/avatars/#{kind}/#{digest(kind, seed)}.svg"
    query.empty? ? path : "#{path}?#{query.to_query}"
  end

  def self.digest(kind, seed)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("avatars"), "#{kind}:#{seed}")
  end

  def self.lookup(kind, digest)
    find_by(kind:, digest:) || fetch(kind, digest)
  end

  def self.fetch(kind, digest)
    failure_key = "avatars/#{kind}/#{digest}/failed"
    return if Rails.cache.exist?(failure_key)

    svg = download(kind, digest)
    if svg.nil?
      Rails.cache.write(failure_key, true, expires_in: FAILURE_TTL)
      return
    end

    create!(kind:, digest:, svg:)
  rescue ActiveRecord::RecordNotUnique
    find_by!(kind:, digest:)
  end

  def self.dicebear_uri(kind, seed)
    URI("#{ENDPOINT}/#{STYLES.fetch(kind)}/svg").tap do |uri|
      uri.query = URI.encode_www_form([["seed", seed], *ANIMATION_VARIANTS.map { |variant| ["animationVariant", variant] }])
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

  def still_svg
    document = Nokogiri::XML(svg)
    document.xpath("//*[local-name()='animate' or local-name()='animateTransform' or local-name()='animateMotion' or local-name()='set']").remove
    document.xpath("//*[local-name()='style']").each { |style| style.content = self.class.still_css(style.content) }
    document.root.to_xml
  end

  def self.still_css(css)
    css.gsub(/@keyframes\s+[\w-]+\s*\{(?:[^{}]*\{[^{}]*\})*[^{}]*\}/, "").gsub(/animation[\w-]*\s*:[^;}]*;?/, "")
  end
end
