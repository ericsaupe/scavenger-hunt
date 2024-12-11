class Vote < ApplicationRecord
  belongs_to :submission

  validates :user_id, presence: true
  validates :user_id, uniqueness: {scope: :submission_id}

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
