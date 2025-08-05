class WorkRatio < ApplicationRecord
  belongs_to :hospital
  belongs_to :period
  belongs_to :employee
  belongs_to :activity
end
