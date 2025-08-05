require 'rails_helper'

RSpec.describe Hospital, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_inclusion_of(:is_active).in_array([true, false]) }
  end

  describe 'associations' do
    it { should have_many(:hospital_users).dependent(:destroy) }
    it { should have_many(:users).through(:hospital_users) }
    it { should have_many(:periods).dependent(:destroy) }
    it { should have_many(:departments).dependent(:destroy) }
    it { should have_many(:accounts).dependent(:destroy) }
    it { should have_many(:activities).dependent(:destroy) }
    it { should have_many(:processes).dependent(:destroy) }
    it { should have_many(:employees).dependent(:destroy) }
    it { should have_many(:job_statuses).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:active_hospital) { create(:hospital, is_active: true) }
    let!(:inactive_hospital) { create(:hospital, is_active: false) }

    describe '.active' do
      it 'returns only active hospitals' do
        expect(Hospital.active).to include(active_hospital)
        expect(Hospital.active).not_to include(inactive_hospital)
      end
    end

    describe '.inactive' do
      it 'returns only inactive hospitals' do
        expect(Hospital.inactive).to include(inactive_hospital)
        expect(Hospital.inactive).not_to include(active_hospital)
      end
    end
  end

  describe 'instance methods' do
    let(:hospital) { create(:hospital) }

    describe '#active?' do
      it 'returns true when hospital is active' do
        hospital.is_active = true
        expect(hospital.active?).to be true
      end

      it 'returns false when hospital is inactive' do
        hospital.is_active = false
        expect(hospital.active?).to be false
      end
    end

    describe '#display_name' do
      it 'returns formatted name with code' do
        hospital.code = 'HSP001'
        hospital.name = 'General Hospital'
        expect(hospital.display_name).to eq('HSP001 - General Hospital')
      end
    end

    describe '#current_period' do
      context 'when hospital has active periods' do
        let!(:inactive_period) { create(:period, hospital: hospital, is_active: false) }
        let!(:active_period) { create(:period, hospital: hospital, is_active: true) }

        it 'returns the active period' do
          expect(hospital.current_period).to eq(active_period)
        end
      end

      context 'when hospital has no active periods' do
        before { create(:period, hospital: hospital, is_active: false) }

        it 'returns nil' do
          expect(hospital.current_period).to be_nil
        end
      end
    end

    describe '#total_departments' do
      before { create_list(:department, 3, hospital: hospital) }

      it 'returns the total number of departments' do
        expect(hospital.total_departments).to eq(3)
      end
    end

    describe '#total_employees' do
      before do
        period = create(:period, hospital: hospital)
        create_list(:employee, 5, hospital: hospital, period: period)
      end

      it 'returns the total number of employees across all periods' do
        expect(hospital.total_employees).to eq(5)
      end
    end

    describe '#can_be_deleted?' do
      context 'when hospital has no associated data' do
        it 'returns true' do
          expect(hospital.can_be_deleted?).to be true
        end
      end

      context 'when hospital has periods' do
        before { create(:period, hospital: hospital) }

        it 'returns false' do
          expect(hospital.can_be_deleted?).to be false
        end
      end

      context 'when hospital has users' do
        let(:user) { create(:user) }
        before { hospital.users << user }

        it 'returns false' do
          expect(hospital.can_be_deleted?).to be false
        end
      end
    end
  end

  describe 'factory' do
    it 'creates a valid hospital' do
      hospital = build(:hospital)
      expect(hospital).to be_valid
    end

    it 'creates hospital with periods' do
      hospital = create(:hospital, :with_periods)
      expect(hospital.periods.count).to eq(2)
    end

    it 'creates hospital with departments' do
      hospital = create(:hospital, :with_departments)
      expect(hospital.departments.count).to eq(3)
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      let(:hospital) { create(:hospital) }

      context 'when hospital has associated data' do
        before { create(:period, hospital: hospital) }

        it 'prevents deletion and adds error' do
          expect(hospital.destroy).to be false
          expect(hospital.errors[:base]).to include('Cannot delete hospital with associated data')
        end
      end

      context 'when hospital has no associated data' do
        it 'allows deletion' do
          expect(hospital.destroy).to be_truthy
        end
      end
    end
  end
end