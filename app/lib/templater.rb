# frozen_string_literal: true

class Templater
  TEMPLATES = [] # rubocop:disable Style/MutableConstant

  def self.load_hunts
    Rails.root.glob("app/templates/*.yml") do |filename|
      yaml_contents = File.read(filename)
      hunt_config = YAML.safe_load(yaml_contents, symbolize_names: true)
      define_singleton_method hunt_config[:name].parameterize.underscore.to_sym do
        hunt = Hunt.create!(
          name: hunt_config[:name],
          categories: hunt_config[:categories].map do |category|
            Category.new(
              name: category[:name],
              points: category[:points],
              items: category[:items].map { |item| Item.new(name: item) }
            )
          end
        )
        if hunt_config.dig(:victory_item_name)
          hunt.update!(victory_item: hunt.items.find_by!(name: hunt_config[:victory_item_name]))
        end
        hunt
      end
      TEMPLATES << hunt_config
    end
  end

  def self.create_hunt!(name)
    send(name.parameterize.underscore)
  end

  def self.templates
    TEMPLATES
  end

  def self.supported_hunts
    TEMPLATES.pluck(:name).sort
  end

  def self.popular_templates
    ["Neighborhood Navigator", "Christmas Light Spectacle"]
  end
end
