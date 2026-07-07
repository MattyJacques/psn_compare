class TrophySkip < ApplicationRecord
  belongs_to :trophy
  validates :trophy_id, uniqueness: true
end
