namespace :flipper do
  desc "Turn a feature on for everyone, e.g. rake flipper:enable[chat]"
  task :enable, [:feature] => :environment do |_task, args|
    feature = args.fetch(:feature) { abort "Usage: rake flipper:enable[feature]" }
    Flipper.enable(feature)
    puts "#{feature} is on"
  end

  desc "Turn a feature off for everyone, e.g. rake flipper:disable[chat]"
  task :disable, [:feature] => :environment do |_task, args|
    feature = args.fetch(:feature) { abort "Usage: rake flipper:disable[feature]" }
    Flipper.disable(feature)
    puts "#{feature} is off"
  end
end
