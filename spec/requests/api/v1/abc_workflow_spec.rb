require 'rails_helper'

RSpec.describe "Api::V1::ABC Workflow Integration", type: :request do
  let(:hospital) { create(:hospital) }
  let(:admin_user) { create(:user, hospital: hospital, role: 'admin') }
  let(:auth_headers) { { 'Authorization' => "Bearer #{admin_user.generate_jwt_token}" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
    allow_any_instance_of(ApplicationController).to receive(:current_hospital).and_return(hospital)
  end

  describe "Complete ABC Workflow" do
    let!(:period) { create(:period, hospital: hospital, start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month) }
    let!(:department) { create(:department, hospital: hospital, name: "Emergency Department") }
    
    context "End-to-end ABC calculation workflow" do
      it "completes full ABC calculation process" do
        # Step 1: Create basic master data
        
        # Create accounts with cost inputs
        account1 = create(:account, hospital: hospital, period: period, department: department, name: "Medical Supplies")
        account2 = create(:account, hospital: hospital, period: period, department: department, name: "Personnel Costs")
        
        create(:cost_input, account: account1, cost_type: 'direct', amount: 500000)
        create(:cost_input, account: account2, cost_type: 'indirect', amount: 300000)
        
        # Create activities
        activity1 = create(:activity, hospital: hospital, department: department, name: "Patient Triage")
        activity2 = create(:activity, hospital: hospital, department: department, name: "Emergency Treatment")
        
        # Create processes
        process1 = create(:process, hospital: hospital, name: "Emergency Care Process")
        process2 = create(:process, hospital: hospital, name: "Discharge Process")
        
        # Create drivers
        driver1 = create(:driver, hospital: hospital, name: "Number of Patients", unit: "patients")
        driver2 = create(:driver, hospital: hospital, name: "Treatment Hours", unit: "hours")
        
        # Create employees and work ratios
        employee1 = create(:employee, hospital: hospital, department: department, name: "Dr. Smith")
        employee2 = create(:employee, hospital: hospital, department: department, name: "Nurse Johnson")
        
        create(:work_ratio, employee: employee1, activity: activity1, ratio: 0.6)
        create(:work_ratio, employee: employee1, activity: activity2, ratio: 0.4)
        create(:work_ratio, employee: employee2, activity: activity1, ratio: 0.3)
        create(:work_ratio, employee: employee2, activity: activity2, ratio: 0.7)
        
        # Create activity-process mappings
        create(:activity_process_mapping, activity: activity1, process: process1, allocation_percentage: 80.0)
        create(:activity_process_mapping, activity: activity1, process: process2, allocation_percentage: 20.0)
        create(:activity_process_mapping, activity: activity2, process: process1, allocation_percentage: 100.0)
        
        # Step 2: Initiate ABC calculation
        calculation_params = {
          abc_calculation: {
            period_id: period.id,
            name: "Emergency Department ABC Analysis",
            description: "Monthly ABC calculation for Emergency Department"
          }
        }
        
        expect {
          post "/api/v1/abc_calculations", params: calculation_params, headers: auth_headers
        }.to change(JobStatus, :count).by(1)
        
        expect(response).to have_http_status(:accepted)
        calculation_response = JSON.parse(response.body)
        job_id = calculation_response['job_id']
        
        # Step 3: Monitor calculation progress
        get "/api/v1/abc_calculations/#{job_id}/status", headers: auth_headers
        expect(response).to have_http_status(:ok)
        
        status_response = JSON.parse(response.body)
        expect(status_response['job_id']).to eq(job_id)
        expect(status_response['status']).to be_in(['pending', 'in_progress', 'completed'])
        
        # Step 4: Simulate calculation completion by creating result data
        create(:activity_cost, activity: activity1, period: period, allocated_cost: 320000)
        create(:activity_cost, activity: activity2, period: period, allocated_cost: 480000)
        create(:process_cost_assignment, process: process1, period: period, assigned_cost: 640000)
        create(:process_cost_assignment, process: process2, period: period, assigned_cost: 160000)
        
        # Update job status to completed
        job_status = JobStatus.find_by(job_id: job_id)
        job_status.update!(status: 'completed', progress: 100)
        
        # Step 5: Retrieve calculation results
        get "/api/v1/abc_calculations/#{job_id}/results", headers: auth_headers
        expect(response).to have_http_status(:ok)
        
        results_response = JSON.parse(response.body)
        expect(results_response).to have_key('period_id')
        expect(results_response).to have_key('departments')
        expect(results_response).to have_key('activities')
        expect(results_response).to have_key('processes')
        expect(results_response).to have_key('summary')
        
        # Verify calculation results
        expect(results_response['activities'].length).to eq(2)
        expect(results_response['processes'].length).to eq(2)
        expect(results_response['summary']['total_cost']).to eq(800000)
        
        # Step 6: Generate reports
        departments_response = nil
        get "/api/v1/reports/departments", params: { period_id: period.id }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        departments_response = JSON.parse(response.body)
        expect(departments_response.first['name']).to eq("Emergency Department")
        
        activities_response = nil
        get "/api/v1/reports/activities", params: { period_id: period.id }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        activities_response = JSON.parse(response.body)
        expect(activities_response.length).to eq(2)
        
        processes_response = nil
        get "/api/v1/reports/processes", params: { period_id: period.id }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        processes_response = JSON.parse(response.body)
        expect(processes_response.length).to eq(2)
        
        # Step 7: Generate KPI report
        get "/api/v1/reports/kpi", params: { period_id: period.id }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        
        kpi_response = JSON.parse(response.body)
        expect(kpi_response['total_cost']).to eq(800000)
        expect(kpi_response['department_count']).to eq(1)
        expect(kpi_response['activity_count']).to eq(2)
        expect(kpi_response['process_count']).to eq(2)
        
        # Step 8: Export comprehensive report
        export_params = {
          export: {
            period_id: period.id,
            format: 'excel',
            report_type: 'comprehensive',
            include_departments: true,
            include_activities: true,
            include_processes: true
          }
        }
        
        expect {
          post "/api/v1/reports/export", params: export_params, headers: auth_headers
        }.to change(JobStatus, :count).by(1)
        
        expect(response).to have_http_status(:accepted)
        export_response = JSON.parse(response.body)
        export_job_id = export_response['job_id']
        
        # Monitor export progress
        get "/api/v1/reports/export/#{export_job_id}/status", headers: auth_headers
        expect(response).to have_http_status(:ok)
        
        export_status_response = JSON.parse(response.body)
        expect(export_status_response['job_id']).to eq(export_job_id)
        expect(export_status_response['status']).to be_in(['pending', 'in_progress', 'completed'])
      end
    end

    context "Error handling in workflow" do
      it "handles calculation errors gracefully" do
        # Create minimal invalid data (no cost inputs)
        incomplete_calculation_params = {
          abc_calculation: {
            period_id: period.id,
            name: "Incomplete Test Calculation",
            description: "Test calculation with missing data"
          }
        }
        
        post "/api/v1/abc_calculations", params: incomplete_calculation_params, headers: auth_headers
        expect(response).to have_http_status(:accepted)
        
        calculation_response = JSON.parse(response.body)
        job_id = calculation_response['job_id']
        
        # Simulate job failure
        job_status = JobStatus.find_by(job_id: job_id)
        job_status.update!(
          status: 'failed',
          error_message: 'Insufficient cost data for calculation'
        )
        
        # Check error status
        get "/api/v1/abc_calculations/#{job_id}/status", headers: auth_headers
        expect(response).to have_http_status(:ok)
        
        status_response = JSON.parse(response.body)
        expect(status_response['status']).to eq('failed')
        expect(status_response['error_message']).to include('Insufficient cost data')
      end

      it "validates calculation prerequisites" do
        # Try to run calculation without required data
        empty_period = create(:period, hospital: hospital)
        
        calculation_params = {
          abc_calculation: {
            period_id: empty_period.id,
            name: "Empty Period Test",
            description: "Test with no data"
          }
        }
        
        post "/api/v1/abc_calculations", params: calculation_params, headers: auth_headers
        
        # Should still accept the request but job will fail during execution
        expect(response).to have_http_status(:accepted)
      end
    end

    context "Multi-department workflow" do
      let!(:department2) { create(:department, hospital: hospital, name: "Radiology Department") }
      
      it "handles multi-department calculations" do
        # Create data for both departments
        [department, department2].each_with_index do |dept, index|
          account = create(:account, hospital: hospital, period: period, department: dept, name: "Account #{index + 1}")
          create(:cost_input, account: account, amount: (index + 1) * 100000)
          
          activity = create(:activity, hospital: hospital, department: dept, name: "Activity #{index + 1}")
          create(:activity_cost, activity: activity, period: period, allocated_cost: (index + 1) * 50000)
        end
        
        # Run calculation
        calculation_params = {
          abc_calculation: {
            period_id: period.id,
            name: "Multi-Department ABC Analysis",
            description: "ABC calculation across multiple departments"
          }
        }
        
        post "/api/v1/abc_calculations", params: calculation_params, headers: auth_headers
        expect(response).to have_http_status(:accepted)
        
        calculation_response = JSON.parse(response.body)
        job_id = calculation_response['job_id']
        
        # Update job to completed
        job_status = JobStatus.find_by(job_id: job_id)
        job_status.update!(status: 'completed', progress: 100)
        
        # Check results include both departments
        get "/api/v1/abc_calculations/#{job_id}/results", headers: auth_headers
        expect(response).to have_http_status(:ok)
        
        results_response = JSON.parse(response.body)
        expect(results_response['departments'].length).to eq(2)
        
        # Check department reports
        get "/api/v1/reports/departments", params: { period_id: period.id }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        
        departments_response = JSON.parse(response.body)
        expect(departments_response.length).to eq(2)
        
        department_names = departments_response.map { |d| d['name'] }
        expect(department_names).to include("Emergency Department", "Radiology Department")
      end
    end
  end
end