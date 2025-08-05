class ActivityProcessMapping < ApplicationRecord
  belongs_to :hospital
  belongs_to :period
  belongs_to :activity
  belongs_to :process
  belongs_to :driver
end
