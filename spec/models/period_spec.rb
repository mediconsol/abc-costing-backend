require 'rails_helper'

RSpec.describe Period, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_inclusion_of(:is_active).in_array([true, false]) }
    it { should validate_inclusion_of(:calculation_status).in_array(%w[pending in_progress completed failed cancelled]) }
  end

  describe 'associations' do
    it { should belong_to(:hospital) }
    it { should have_many(:departments).dependent(:destroy) }
    it { should have_many(:accounts).dependent(:destroy) }
    it { should have_many(:activities).dependent(:destroy) }
    it { should have_many(:processes).dependent(:destroy) }
    it { should have_many(:employees).dependent(:destroy) }
    it { should have_many(:account_activity_mappings).dependent(:destroy) }
    it { should have_many(:activity_process_mappings).dependent(:destroy) }
    it { should have_many(:work_ratios).dependent(:destroy) }
    it { should have_many(:job_statuses).dependent(:destroy) }
  end

  describe 'scopes' do
    let(:hospital) { create(:hospital) }
    let!(:active_period) { create(:period, hospital: hospital, is_active: true) }
    let!(:inactive_period) { create(:period, hospital: hospital, is_active: false) }
    let!(:completed_period) { create(:period, hospital: hospital, :calculated) }
    let!(:failed_period) { create(:period, hospital: hospital, :failed) }

    describe '.active' do
      it 'returns only active periods' do
        expect(Period.active).to include(active_period)
        expect(Period.active).not_to include(inactive_period)
      end
    end

    describe '.by_status' do
      it 'returns periods with specified calculation status' do
        expect(Period.by_status('completed')).to include(completed_period)
        expect(Period.by_status('failed')).to include(failed_period)
      end
    end

    describe '.calculated' do
      it 'returns only calculated periods' do
        expect(Period.calculated).to include(completed_period)
        expect(Period.calculated).not_to include(active_period)
      end
    end

    describe '.recent' do
      it 'returns periods ordered by creation date desc' do
        periods = Period.recent
        expect(periods.first.created_at).to be >= periods.last.created_at
      end
    end
  end

  describe 'validations with custom logic' do
    let(:hospital) { create(:hospital) }

    describe 'end_date_after_start_date' do
      it 'is valid when end_date is after start_date' do
        period = build(:period, 
          hospital: hospital,
          start_date: Date.current,
          end_date: Date.current + 1.year
        )
        expect(period).to be_valid
      end

      it 'is invalid when end_date is before start_date' do
        period = build(:period,
          hospital: hospital,
          start_date: Date.current,
          end_date: Date.current - 1.day
        )
        expect(period).not_to be_valid
        expect(period.errors[:end_date]).to include('must be after start date')
      end
    end

    describe 'unique_active_period_per_hospital' do
      let!(:active_period) { create(:period, hospital: hospital, is_active: true) }

      it 'allows multiple inactive periods' do
        period = build(:period, hospital: hospital, is_active: false)
        expect(period).to be_valid
      end

      it 'prevents multiple active periods for same hospital' do
        period = build(:period, hospital: hospital, is_active: true)
        expect(period).not_to be_valid
        expect(period.errors[:is_active]).to include('Hospital can only have one active period')
      end

      it 'allows active period for different hospital' do
        other_hospital = create(:hospital)
        period = build(:period, hospital: other_hospital, is_active: true)
        expect(period).to be_valid
      end
    end
  end

  describe 'instance methods' do
    let(:period) { create(:period, :with_full_setup) }

    describe '#active?' do
      it 'returns true when period is active' do
        period.is_active = true
        expect(period.active?).to be true
      end

      it 'returns false when period is inactive' do
        period.is_active = false
        expect(period.active?).to be false
      end
    end

    describe '#calculation_completed?' do
      it 'returns true when calculation status is completed' do
        period.calculation_status = 'completed'
        expect(period.calculation_completed?).to be true
      end

      it 'returns false when calculation status is not completed' do
        period.calculation_status = 'pending'
        expect(period.calculation_completed?).to be false
      end
    end

    describe '#can_calculate?' do
      before { period.calculation_status = 'pending' }

      context 'when period has required data' do
        it 'returns true' do
          expect(period.can_calculate?).to be true
        end
      end

      context 'when calculation is in progress' do
        before { period.calculation_status = 'in_progress' }

        it 'returns false' do
          expect(period.can_calculate?).to be false
        end
      end
    end

    describe '#duration_in_days' do
      it 'calculates duration between start and end dates' do
        period.start_date = Date.parse('2024-01-01')
        period.end_date = Date.parse('2024-12-31')
        expect(period.duration_in_days).to eq(365)
      end
    end

    describe '#total_cost' do
      it 'returns sum of all activities total cost' do
        # Assuming activities have costs set via factory
        expected_cost = period.activities.sum(&:total_cost)
        expect(period.total_cost).to eq(expected_cost)
      end
    end

    describe '#total_revenue' do
      it 'returns sum of all billable processes revenue' do
        expected_revenue = period.processes.billable.sum(&:total_revenue)
        expect(period.total_revenue).to eq(expected_revenue)
      end
    end

    describe '#calculation_duration' do
      context 'when calculation is completed' do
        before do
          period.calculation_started_at = 1.hour.ago
          period.calculation_completed_at = Time.current
        end

        it 'returns duration in seconds' do
          expect(period.calculation_duration).to be_within(5).of(3600)
        end
      end

      context 'when calculation is not completed' do
        before do
          period.calculation_started_at = nil
          period.calculation_completed_at = nil
        end

        it 'returns nil' do
          expect(period.calculation_duration).to be_nil
        end
      end
    end

    describe '#progress_percentage' do
      context 'when calculation is completed' do
        before { period.calculation_status = 'completed' }

        it 'returns 100' do
          expect(period.progress_percentage).to eq(100)
        end
      end

      context 'when calculation is in progress' do
        before { period.calculation_status = 'in_progress' }

        it 'returns partial percentage' do
          expect(period.progress_percentage).to be_between(0, 100)
        end
      end

      context 'when calculation is pending' do
        before { period.calculation_status = 'pending' }

        it 'returns 0' do
          expect(period.progress_percentage).to eq(0)
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      let(:period) { create(:period, :calculated) }

      context 'when period has calculation data' do
        it 'prevents deletion and adds error' do
          expect(period.destroy).to be false
          expect(period.errors[:base]).to include('Cannot delete period with calculation results')
        end
      end

      context 'when period has no calculation data' do
        let(:pending_period) { create(:period) }

        it 'allows deletion' do
          expect(pending_period.destroy).to be_truthy
        end
      end
    end

    describe 'after_update' do
      let(:period) { create(:period, is_active: false) }

      context 'when setting is_active to true' do
        it 'deactivates other active periods for same hospital' do
          other_active = create(:period, hospital: period.hospital, is_active: true)
          
          period.update!(is_active: true)
          
          expect(other_active.reload.is_active).to be false
        end
      end
    end
  end

  describe 'factory' do
    it 'creates a valid period' do
      period = build(:period)
      expect(period).to be_valid
    end

    it 'creates calculated period' do
      period = create(:period, :calculated)
      expect(period.calculation_status).to eq('completed')
      expect(period.last_calculated_at).to be_present
    end

    it 'creates period with full setup' do
      period = create(:period, :with_full_setup)
      expect(period.departments.count).to eq(2)
      expect(period.accounts.count).to eq(3)
      expect(period.activities.count).to eq(4)
      expect(period.processes.count).to eq(2)
      expect(period.employees.count).to eq(3)
    end
  end
end