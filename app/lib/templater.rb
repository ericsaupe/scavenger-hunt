# frozen_string_literal: true

class Templater
  def self.templates
    @templates ||= Rails.root.glob("app/templates/*.yml").map do |filename|
      HuntTemplate.new(**YAML.safe_load_file(filename, symbolize_names: true))
    end
  end

  def self.find!(slug)
    templates.find { |template| template.slug == slug.to_s.parameterize } or
      raise ActiveRecord::RecordNotFound, "There is no #{slug.inspect} template"
  end

  def self.create_hunt!(name)
    template = find!(name)
    hunt = Hunt.create!(
      name: template.name,
      categories: template.categories.map do |category|
        Category.new(
          name: category.name,
          points: category.points,
          items: category.items.map { |item| Item.new(name: item) }
        )
      end
    )
    if template.victory_item_name
      hunt.update!(victory_item: hunt.items.find_by!(name: template.victory_item_name))
    end
    hunt
  end

  def self.supported_hunts
    templates.map(&:name).sort
  end

  def self.popular_templates
    ["Neighborhood Navigator", "Christmas Light Spectacle"]
  end
end
