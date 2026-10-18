# frozen_string_literal: true

class HuntTemplate
  Category = Data.define(:name, :points, :items) do
    def possible_score
      points * items.size
    end
  end

  attr_reader :name, :description, :categories, :victory_item_name

  def initialize(name:, categories:, description: nil, image_path: nil, victory_item_name: nil)
    @name = name
    @description = description
    @image_path = image_path
    @victory_item_name = victory_item_name
    @categories = categories.map { |category| Category.new(**category) }
  end

  def slug
    name.parameterize
  end
  alias_method :to_param, :slug

  def image_path
    @image_path || "templates/scavenger.jpg"
  end

  def item_count
    categories.sum { |category| category.items.size }
  end

  def points_range
    Range.new(*categories.map(&:points).minmax)
  end

  def possible_score
    categories.sum(&:possible_score)
  end
end
