class RevenueCode < ApplicationRecord
  belongs_to :hospital
  belongs_to :period
  belongs_to :business_process
end
