class Vote < ApplicationRecord
  belongs_to :submission

  validates :user_id, presence: true

  delegate :hunt, to: :submission

  scope :denied, -> { where(value: "deny") }
  scope :loved, -> { where(value: "love") }

  def loved?
    value == "love"
  end

  def denied?
    value == "deny"
  end
end
