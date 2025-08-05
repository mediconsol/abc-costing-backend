require 'rails_helper'

RSpec.describe AbcCalculationService, type: :service do
  let(:hospital) { create(:hospital) }
  let(:period) { create(:period, :with_full_setup, hospital: hospital) }
  let(:service) { described_class.new(hospital, period) }

  describe '#initialize' do
    it 'sets hospital and period' do
      expect(service.hospital).to eq(hospital)
      expect(service.period).to eq(period)
      expect(service.errors).to be_empty
    end
  end

  describe '#execute' do
    context 'when prerequisites are met' do
      before do
        # Setup required data
        create_abc_test_data
      end

      it 'executes all calculation stages successfully' do
        expect(ResourceCostAllocationService).to receive(:new).with(hospital, period).and_call_original
        expect(ActivityCostPoolService).to receive(:new).with(hospital, period).and_call_original
        expect(ProcessCostAssignmentService).to receive(:new).with(hospital, period).and_call_original

        result = service.execute

        expect(result).to be true
        expect(period.reload.calculation_status).to eq('completed')
        expect(period.last_calculated_at).to be_present
      end

      it 'updates period status to completed' do
        service.execute
        
        period.reload
        expect(period.calculation_status).to eq('completed')
        expect(period.last_calculated_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'when prerequisites are not met' do
      it 'returns false and sets errors' do
        result = service.execute

        expect(result).to be false
        expect(service.errors).not_to be_empty
      end

      it 'does not update period status' do
        original_status = period.calculation_status
        service.execute

        expect(period.reload.calculation_status).to eq(original_status)
      end
    end

    context 'when a stage fails' do
      before do
        create_abc_test_data
        allow_any_instance_of(ResourceCostAllocationService).to receive(:execute)
          .and_return({ success: false, errors: ['Stage 1 failed'] })
      end

      it 'rolls back transaction and sets period to failed' do
        result = service.execute

        expect(result).to be false
        expect(period.reload.calculation_status).to eq('failed')
        expect(service.errors).to include('Stage 1 failed: Stage 1 failed')
      end
    end

    context 'when an exception occurs' do
      before do
        create_abc_test_data
        allow_any_instance_of(ResourceCostAllocationService).to receive(:execute)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'handles exception and sets period to failed' do
        result = service.execute

        expect(result).to be false
        expect(period.reload.calculation_status).to eq('failed')
        expect(service.errors).to include('Unexpected error')
      end
    end
  end

  describe '#calculation_summary' do
    let(:summary) { service.calculation_summary }

    it 'returns comprehensive calculation summary' do
      expect(summary).to be_a(Hash)
      expect(summary).to include(:hospital_id, :hospital_name, :period_id, :period_name)
      expect(summary).to include(:total_accounts, :total_activities, :total_processes)
      expect(summary).to include(:total_cost_allocated, :mapped_accounts, :mapped_activities)
    end

    it 'includes correct hospital and period information' do
      expect(summary[:hospital_id]).to eq(hospital.id)
      expect(summary[:hospital_name]).to eq(hospital.name)
      expect(summary[:period_id]).to eq(period.id)
      expect(summary[:period_name]).to eq(period.name)
    end

    it 'includes calculated metrics when available' do
      expect(summary[:calculated_at]).to eq(period.last_calculated_at)
      expect(summary[:status]).to eq(period.calculation_status)
    end
  end

  describe '#validate_prerequisites' do
    context 'when all prerequisites are met' do
      before { create_abc_test_data }

      it 'returns true and has no errors' do
        result = service.send(:validate_prerequisites)
        expect(result).to be true
        expect(service.errors).to be_empty
      end
    end

    context 'when cost inputs are missing' do
      it 'adds error for missing cost inputs' do
        result = service.send(:validate_prerequisites)
        expect(result).to be false
        expect(service.errors).to include(/No cost inputs found/)
      end
    end

    context 'when account-activity mappings are missing' do
      before do
        # Create cost inputs but no mappings
        account = create(:account, :with_cost_inputs, hospital: hospital, period: period)
      end

      it 'adds error for missing account-activity mappings' do
        result = service.send(:validate_prerequisites)
        expect(result).to be false
        expect(service.errors).to include(/No account-activity mappings found/)
      end
    end

    context 'when activity-process mappings are missing' do
      before do
        account = create(:account, :with_cost_inputs, hospital: hospital, period: period)
        activity = create(:activity, hospital: hospital, period: period)
        create(:account_activity_mapping, 
          hospital: hospital, 
          period: period, 
          account: account, 
          activity: activity
        )
      end

      it 'adds error for missing activity-process mappings' do
        result = service.send(:validate_prerequisites)
        expect(result).to be false
        expect(service.errors).to include(/No activity-process mappings found/)
      end
    end

    context 'when work ratios are missing' do
      before do
        account = create(:account, :with_cost_inputs, hospital: hospital, period: period)
        activity = create(:activity, hospital: hospital, period: period)
        process = create(:process, hospital: hospital, period: period, activity: activity)
        
        create(:account_activity_mapping, 
          hospital: hospital, 
          period: period, 
          account: account, 
          activity: activity
        )
        create(:activity_process_mapping,
          hospital: hospital,
          period: period,
          activity: activity,
          process: process
        )
      end

      it 'adds error for missing work ratios' do
        result = service.send(:validate_prerequisites)
        expect(result).to be false
        expect(service.errors).to include(/No employee work ratios found/)
      end
    end
  end

  private

  def create_abc_test_data
    # Create accounts with cost inputs
    account1 = create(:account, :with_cost_inputs, hospital: hospital, period: period)
    account2 = create(:account, :with_cost_inputs, hospital: hospital, period: period)

    # Create activities
    department = create(:department, hospital: hospital, period: period)
    activity1 = create(:activity, hospital: hospital, period: period, department: department)
    activity2 = create(:activity, hospital: hospital, period: period, department: department)

    # Create processes
    process1 = create(:process, hospital: hospital, period: period, activity: activity1)
    process2 = create(:process, hospital: hospital, period: period, activity: activity2)

    # Create employees
    employee1 = create(:employee, hospital: hospital, period: period, department: department)
    employee2 = create(:employee, hospital: hospital, period: period, department: department)

    # Create account-activity mappings
    create(:account_activity_mapping,
      hospital: hospital,
      period: period,
      account: account1,
      activity: activity1,
      ratio: 0.6
    )
    create(:account_activity_mapping,
      hospital: hospital,
      period: period,
      account: account1,
      activity: activity2,
      ratio: 0.4
    )
    create(:account_activity_mapping,
      hospital: hospital,
      period: period,
      account: account2,
      activity: activity2,
      ratio: 1.0
    )

    # Create activity-process mappings
    create(:activity_process_mapping,
      hospital: hospital,
      period: period,
      activity: activity1,
      process: process1,
      rate: 1.0
    )
    create(:activity_process_mapping,
      hospital: hospital,
      period: period,
      activity: activity2,
      process: process2,
      rate: 1.0
    )

    # Create work ratios
    create(:work_ratio,
      hospital: hospital,
      period: period,
      employee: employee1,
      activity: activity1,
      ratio: 0.8,
      hours_per_period: 1600
    )
    create(:work_ratio,
      hospital: hospital,
      period: period,
      employee: employee2,
      activity: activity2,
      ratio: 0.7,
      hours_per_period: 1400
    )
  end
end