class Employee < ApplicationRecord
  belongs_to :hospital
  belongs_to :period
  belongs_to :department
end
