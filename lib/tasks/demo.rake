require "net/http"
require "vips"

namespace :demo do
  desc "Seed a finished hunt with several teams, photos, videos, loves and flags for rehearsing the big-screen show. CODE, TEMPLATE and OWNER are optional."
  task hunt: :environment do
    DemoHunt.new(
      code: ENV.fetch("CODE", "BLOCK"),
      template: ENV.fetch("TEMPLATE", "Neighborhood Navigator"),
      owner_id: ENV["OWNER"].presence
    ).build!
  end
end

class DemoHunt
  TEAMS = ["Blue Bandits", "Red Rockets", "Green Machine", "Owls", "Foxes"].freeze
  FOUND_PER_TEAM = [27, 23, 19, 15, 9].freeze
  UNFOUND_ITEMS = 4
  VIDEO_COUNT = 5
  VIEWERS = 28
  FLAG_THRESHOLD = 3
  PHOTO_CACHE = Rails.root.join("tmp/demo_photos")
  FALLBACK_SOURCES = %w[app/assets/images/hero.jpg spec/fixtures/test.jpg app/assets/images/templates/neighborhood.jpg app/assets/images/templates/camping.jpg app/assets/images/templates/beach.jpg app/assets/images/templates/team.jpg].freeze

  def initialize(code:, template:, owner_id: nil)
    @code = code.upcase
    @template = template
    @owner_id = owner_id
    @random = Random.new(@code.sum)
    @viewers = Array.new(VIEWERS) { |i| "demo-viewer-#{i + 1}" }
  end

  def build!
    ActiveStorage::Current.url_options = {host: "localhost", port: 3000}
    FileUtils.mkdir_p(PHOTO_CACHE)

    Hunt.find_by(code: @code)&.destroy!
    hunt = Templater.create_hunt!(@template)
    hunt.update!(
      code: @code,
      name: "Maple Street Block Party",
      starts_at: 3.hours.ago,
      ends_at: 70.minutes.ago,
      max_downvotes_to_lose_points: FLAG_THRESHOLD,
      lock_results: false,
      lock_password: nil,
      owner_id: @owner_id
    )

    items = hunt.items.order(:id).to_a
    teams = TEAMS.map { |name| hunt.start_a_new_team(name) }
    @item_slots = items.each_with_index.to_h
    @team_slots = teams.each_with_index.to_h
    plan = found_plan(items, teams)
    submissions = attach_media(hunt, plan)
    cast_votes(submissions)

    report(hunt, teams, submissions)
  end

  private

  def found_plan(items, teams)
    unfound = items.last(UNFOUND_ITEMS)
    everyone = items.first
    pool = items - unfound - [everyone]
    plan = []
    teams.each_with_index do |team, i|
      chosen = [everyone, *pool.sample(FOUND_PER_TEAM[i] - 1, random: @random)]
      chosen.each { |item| plan << [team, item] }
    end
    plan.sort_by { |team, item| [item.id, team.id] }
  end

  def attach_media(hunt, plan)
    video_slots = plan.sample(VIDEO_COUNT, random: @random).to_set
    window = (hunt.starts_at.to_i..hunt.ends_at.to_i)
    plan.each_with_index.map do |(team, item), index|
      submission = Submission.find_by!(team:, item:)
      captured_at = Time.zone.at(@random.rand(window))
      file = video_slots.include?([team, item]) ? video_file : photo_file(item, team, index)
      submission.update!(photo: file, captured_at:)
      $stdout.print "\rattached #{index + 1} of #{plan.size}"
      submission
    end.tap { $stdout.puts }
  end

  def video_file
    {io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "MOV_#{@random.rand(1000..9999)}.mp4", content_type: "video/mp4"}
  end

  def photo_file(item, team, index)
    portrait = @random.rand < 0.35
    width, height = portrait ? [1200, 1600] : [1600, 1200]
    seed = "#{@code}-item#{@item_slots.fetch(item)}-team#{@team_slots.fetch(team)}-#{width}x#{height}"
    path = PHOTO_CACHE.join("#{seed}.jpg")
    download_photo(seed, width, height, path) unless path.exist?
    generate_photo(width, height, path) unless path.exist?
    {io: File.open(path), filename: "IMG_#{4000 + index}.jpg", content_type: "image/jpeg"}
  end

  def download_photo(seed, width, height, path)
    uri = URI("https://picsum.photos/seed/#{seed}/#{width}/#{height}")
    5.times do
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) { |http| http.get(uri.request_uri) }
      case response
      when Net::HTTPRedirection then uri = URI(response["location"])
      when Net::HTTPSuccess
        File.binwrite(path, response.body)
        return
      else return
      end
    end
  rescue
    nil
  end

  def generate_photo(width, height, path)
    source = Vips::Image.new_from_file(Rails.root.join(FALLBACK_SOURCES.sample(random: @random)).to_s, access: :sequential)
    scale = @random.rand(0.55..0.9)
    crop_w = (source.width * scale).to_i
    crop_h = [(crop_w * height / width), source.height].min
    crop_w = crop_h * width / height if crop_h * width / height < crop_w
    left = @random.rand(0..(source.width - crop_w))
    top = @random.rand(0..(source.height - crop_h))
    image = source.crop(left, top, crop_w, crop_h).resize(width.to_f / crop_w)
    image = image.flip(:horizontal) if @random.rand < 0.5
    gain = @random.rand(0.85..1.15)
    image = image.linear([gain, gain * @random.rand(0.95..1.05), gain * @random.rand(0.9..1.1)], [@random.rand(-10..10)] * 3)
    image.write_to_file(path.to_s, Q: 85)
  end

  def cast_votes(submissions)
    star = submissions.reject(&:video?).sample(random: @random)
    flagged = (submissions - [star]).sample(3, random: @random)
    submissions.each do |submission|
      loves = if submission == star
        18
      elsif @random.rand < 0.4
        0
      else
        @random.rand(1..9)
      end
      lovers = @viewers.sample(loves, random: @random)
      lovers.each { |viewer| Vote.create!(submission:, user_id: viewer, value: "love") }

      flags = flagged.index(submission)
      next unless flags

      (@viewers - lovers).sample(flags + 1, random: @random).each { |viewer| Vote.create!(submission:, user_id: viewer, value: "deny") }
      submission.calculate_denied_points
    end
  end

  def report(hunt, teams, submissions)
    puts
    puts "#{hunt.name} (#{hunt.code}) ended #{time_ago_in_words(hunt.ends_at)} ago"
    hunt.results.each_with_index do |result, i|
      puts "  #{i + 1}. #{result[:name].ljust(14)} #{result[:submissions].to_s.rjust(2)} found  #{result[:score].to_s.rjust(3)} pts#{"  (-#{result[:deductions]})" if result[:deductions].positive?}"
    end
    puts "  #{submissions.count(&:video?)} videos, #{Vote.loved.where(submission: submissions).count} loves, #{Vote.denied.where(submission: submissions).count} flags, #{submissions.count(&:denied_points?)} photo no longer counts"
    puts "  #{hunt.items.count - submissions.map(&:item_id).uniq.size} items found by nobody"
    puts
    puts "Results:     http://localhost:3000/scavenger_hunts/#{hunt.code}/results"
    puts "Big screen:  http://localhost:3000/scavenger_hunts/#{hunt.code}/presenter?screen=big"
    puts "Remote:      http://localhost:3000/scavenger_hunts/#{hunt.code}/presenter/remote"
    puts "Checklist:   http://localhost:3000/scavenger_hunts/#{hunt.code}/teams/#{teams.first.id}"
  end

  def time_ago_in_words(time)
    ActionController::Base.helpers.time_ago_in_words(time)
  end
end
