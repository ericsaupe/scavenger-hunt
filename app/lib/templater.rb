# frozen_string_literal: true

class Templater
  SUPPORTED_HUNTS = [].freeze

  def self.load_hunts
    Dir.glob(Rails.root.join('app/templates/*.yml')) do |filename|
      yaml_contents = File.read(filename)
      hunt_config = YAML.safe_load(yaml_contents, symbolize_names: true)
      define_singleton_method hunt_config[:name].parameterize.underscore.to_sym do
        Hunt.create!(
          name: hunt_config[:name],
          categories: hunt_config[:categories].map do |category|
            Category.new(
              name: category[:name],
              points: category[:points],
              items: category[:items].map { |item| Item.new(name: item) }
            )
          end
        )
      end
      SUPPORTED_HUNTS << hunt_config[:name]
    end
  end

  def self.create_hunt!(name)
    send(name.parameterize.underscore)
  end

  def self.supported_hunts
    SUPPORTED_HUNTS.sort
  end
end
