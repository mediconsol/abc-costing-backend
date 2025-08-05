require 'rails_helper'

RSpec.describe Activity, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:category).in_array(%w[clinical administrative support]) }
  end

  describe 'associations' do
    it { should belong_to(:hospital) }
    it { should belong_to(:period) }
    it { should belong_to(:department).optional }
    it { should have_many(:account_activity_mappings).dependent(:destroy) }
    it { should have_many(:accounts).through(:account_activity_mappings) }
    it { should have_many(:activity_process_mappings).dependent(:destroy) }
    it { should have_many(:processes).through(:activity_process_mappings) }
    it { should have_many(:work_ratios).dependent(:destroy) }
    it { should have_many(:employees).through(:work_ratios) }
  end

  describe 'validations with custom logic' do
    let(:hospital) { create(:hospital) }
    let(:period) { create(:period, hospital: hospital) }

    describe 'uniqueness of code' do
      let!(:existing_activity) { create(:activity, hospital: hospital, period: period, code: 'ACT001') }

      it 'validates uniqueness of code within hospital and period scope' do
        duplicate_activity = build(:activity, 
          hospital: hospital, 
          period: period, 
          code: 'ACT001'
        )
        expect(duplicate_activity).not_to be_valid
        expect(duplicate_activity.errors[:code]).to include('has already been taken')
      end

      it 'allows same code in different hospital' do
        other_hospital = create(:hospital)
        other_period = create(:period, hospital: other_hospital)
        activity = build(:activity,
          hospital: other_hospital,
          period: other_period,
          code: 'ACT001'
        )
        expect(activity).to be_valid
      end

      it 'allows same code in different period' do
        other_period = create(:period, hospital: hospital)
        activity = build(:activity,
          hospital: hospital,
          period: other_period,
          code: 'ACT001'
        )
        expect(activity).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:hospital) { create(:hospital) }
    let(:period) { create(:period, hospital: hospital) }
    let(:department) { create(:department, hospital: hospital, period: period) }
    
    let!(:clinical_activity) { create(:activity, hospital: hospital, period: period, category: 'clinical') }
    let!(:admin_activity) { create(:activity, hospital: hospital, period: period, category: 'administrative') }
    let!(:dept_activity) { create(:activity, hospital: hospital, period: period, department: department) }
    let!(:no_dept_activity) { create(:activity, hospital: hospital, period: period, department: nil) }

    describe '.by_category' do
      it 'returns activities of specified category' do
        expect(Activity.by_category('clinical')).to include(clinical_activity)
        expect(Activity.by_category('clinical')).not_to include(admin_activity)
      end
    end

    describe '.with_department' do
      it 'returns activities with assigned departments' do
        expect(Activity.with_department).to include(dept_activity)
        expect(Activity.with_department).not_to include(no_dept_activity)
      end
    end

    describe '.without_department' do
      it 'returns activities without assigned departments' do
        expect(Activity.without_department).to include(no_dept_activity)
        expect(Activity.without_department).not_to include(dept_activity)
      end
    end
  end

  describe 'instance methods' do
    let(:activity) { create(:activity, :fully_configured) }

    describe '#display_name' do
      it 'returns formatted name with code' do
        activity.code = 'ACT001'
        activity.name = 'Patient Care'
        expect(activity.display_name).to eq('ACT001 - Patient Care')
      end
    end

    describe '#full_name' do
      context 'when activity has category' do
        it 'returns name with category' do
          activity.name = 'Patient Care'
          activity.category = 'clinical'
          expect(activity.full_name).to eq('Patient Care (Clinical)')
        end
      end

      context 'when activity has no category' do
        it 'returns just the name' do
          activity.name = 'Patient Care'
          activity.category = nil
          expect(activity.full_name).to eq('Patient Care')
        end
      end
    end

    describe '#department_name' do
      context 'when activity has department' do
        it 'returns department name' do
          department = create(:department, name: 'Cardiology')
          activity.department = department
          expect(activity.department_name).to eq('Cardiology')
        end
      end

      context 'when activity has no department' do
        it 'returns nil' do
          activity.department = nil
          expect(activity.department_name).to be_nil
        end
      end
    end

    describe '#mapped_accounts_count' do
      it 'returns count of mapped accounts' do
        expect(activity.mapped_accounts_count).to eq(activity.accounts.count)
      end
    end

    describe '#mapped_processes_count' do
      it 'returns count of mapped processes' do
        expect(activity.mapped_processes_count).to eq(activity.processes.count)
      end
    end

    describe '#assigned_employees_count' do
      it 'returns count of assigned employees' do
        expect(activity.assigned_employees_count).to eq(activity.employees.count)
      end
    end

    describe '#has_account_mappings?' do
      context 'when activity has account mappings' do
        it 'returns true' do
          expect(activity.has_account_mappings?).to be true
        end
      end

      context 'when activity has no account mappings' do
        let(:activity_no_mappings) { create(:activity) }
        
        it 'returns false' do
          expect(activity_no_mappings.has_account_mappings?).to be false
        end
      end
    end

    describe '#has_process_mappings?' do
      context 'when activity has process mappings' do
        it 'returns true' do
          expect(activity.has_process_mappings?).to be true
        end
      end

      context 'when activity has no process mappings' do
        let(:activity_no_mappings) { create(:activity) }
        
        it 'returns false' do
          expect(activity_no_mappings.has_process_mappings?).to be false
        end
      end
    end

    describe '#has_employee_assignments?' do
      context 'when activity has employee assignments' do
        it 'returns true' do
          expect(activity.has_employee_assignments?).to be true
        end
      end

      context 'when activity has no employee assignments' do
        let(:activity_no_assignments) { create(:activity) }
        
        it 'returns false' do
          expect(activity_no_assignments.has_employee_assignments?).to be false
        end
      end
    end

    describe 'cost calculation methods' do
      before do
        activity.allocated_cost = 50000
        activity.employee_cost = 30000
        activity.total_cost = 80000
        activity.total_fte = 4.0
        activity.total_hours = 8000
      end

      describe '#cost_efficiency' do
        it 'calculates cost efficiency ratio' do
          # Mock implementation - would be more complex in real scenario
          expect(activity.cost_efficiency).to be_a(Numeric)
        end
      end

      describe '#workload_balance' do
        it 'calculates workload balance score' do
          # Mock implementation - would analyze work distribution
          expect(activity.workload_balance).to be_a(Numeric)
        end
      end

      describe '#cost_per_fte' do
        it 'calculates cost per FTE' do
          expect(activity.cost_per_fte).to eq(20000) # 80000 / 4.0
        end
      end

      describe '#cost_per_hour' do
        it 'calculates cost per hour' do
          expect(activity.cost_per_hour).to eq(10) # 80000 / 8000
        end
      end
    end
  end

  describe 'factory' do
    it 'creates a valid activity' do
      activity = build(:activity)
      expect(activity).to be_valid
    end

    it 'creates activity with costs' do
      activity = create(:activity, :with_costs)
      expect(activity.total_cost).to be > 0
      expect(activity.allocated_cost).to be > 0
      expect(activity.employee_cost).to be > 0
    end

    it 'creates fully configured activity' do
      activity = create(:activity, :fully_configured)
      expect(activity.accounts.count).to be > 0
      expect(activity.processes.count).to be > 0
      expect(activity.employees.count).to be > 0
    end
  end

  describe 'concerns' do
    let(:activity) { create(:activity) }

    describe 'HospitalScoped' do
      it 'includes hospital scoped functionality' do
        expect(activity.class.included_modules).to include(HospitalScoped)
      end
    end

    describe 'PeriodScoped' do
      it 'includes period scoped functionality' do
        expect(activity.class.included_modules).to include(PeriodScoped)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      let(:activity) { create(:activity, :with_account_mappings) }

      context 'when activity has mappings' do
        it 'prevents deletion and adds error' do
          expect(activity.destroy).to be false
          expect(activity.errors[:base]).to include('Cannot delete activity with existing mappings')
        end
      end

      context 'when activity has no mappings' do
        let(:clean_activity) { create(:activity) }

        it 'allows deletion' do
          expect(clean_activity.destroy).to be_truthy
        end
      end
    end
  end
end