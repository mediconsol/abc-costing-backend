require 'rails_helper'

RSpec.describe "Api::V1::Reports", type: :request do
  let(:hospital) { create(:hospital) }
  let(:user) { create(:user, hospital: hospital) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{user.generate_jwt_token}" } }
  let(:period) { create(:period, hospital: hospital) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_hospital).and_return(hospital)

    # Create test data
    @department = create(:department, hospital: hospital, name: "Internal Medicine")
    @account = create(:account, hospital: hospital, period: period, department: @department)
    create(:cost_input, account: @account, amount: 500000)
    
    @activity = create(:activity, hospital: hospital, department: @department, name: "Patient Consultation")
    create(:activity_cost, activity: @activity, period: period, allocated_cost: 250000)
    
    @process = create(:process, hospital: hospital, name: "Outpatient Treatment")
    create(:process_cost_assignment, process: @process, period: period, assigned_cost: 150000)
  end

  describe "GET /api/v1/reports/departments" do
    context "with valid period" do
      it "returns department cost summary" do
        get "/api/v1/reports/departments", params: { period_id: period.id }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.first).to have_key('id')
        expect(json_response.first).to have_key('name')
        expect(json_response.first).to have_key('total_cost')
        expect(json_response.first).to have_key('account_count')
        expect(json_response.first).to have_key('activity_count')
      end
    end

    context "without period parameter" do
      it "returns bad request" do
        get "/api/v1/reports/departments", headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('period_id')
      end
    end
  end

  describe "GET /api/v1/reports/activities" do
    context "with valid period" do
      it "returns activity cost summary" do
        get "/api/v1/reports/activities", params: { period_id: period.id }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.first).to have_key('id')
        expect(json_response.first).to have_key('name')
        expect(json_response.first).to have_key('department_name')
        expect(json_response.first).to have_key('allocated_cost')
      end
    end

    context "with department filter" do
      it "returns filtered activities" do
        get "/api/v1/reports/activities", 
            params: { period_id: period.id, department_id: @department.id }, 
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        json_response.each do |activity|
          expect(activity['department_id']).to eq(@department.id)
        end
      end
    end
  end

  describe "GET /api/v1/reports/processes" do
    context "with valid period" do
      it "returns process cost summary" do
        get "/api/v1/reports/processes", params: { period_id: period.id }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.first).to have_key('id')
        expect(json_response.first).to have_key('name')
        expect(json_response.first).to have_key('assigned_cost')
      end
    end
  end

  describe "GET /api/v1/reports/kpi" do
    context "with valid period" do
      it "returns KPI metrics" do
        get "/api/v1/reports/kpi", params: { period_id: period.id }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('total_cost')
        expect(json_response).to have_key('department_count')
        expect(json_response).to have_key('activity_count')
        expect(json_response).to have_key('process_count')
        expect(json_response).to have_key('cost_per_department')
        expect(json_response).to have_key('top_cost_departments')
        expect(json_response).to have_key('top_cost_activities')
      end
    end

    context "with comparison period" do
      let(:previous_period) { create(:period, hospital: hospital, start_date: 1.year.ago, end_date: 10.months.ago) }

      before do
        # Create comparison data
        prev_account = create(:account, hospital: hospital, period: previous_period, department: @department)
        create(:cost_input, account: prev_account, amount: 400000)
      end

      it "returns KPI metrics with comparison" do
        get "/api/v1/reports/kpi", 
            params: { period_id: period.id, compare_period_id: previous_period.id }, 
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('comparison')
        expect(json_response['comparison']).to have_key('cost_change_percentage')
        expect(json_response['comparison']).to have_key('cost_change_amount')
      end
    end
  end

  describe "POST /api/v1/reports/export" do
    let(:valid_export_params) do
      {
        export: {
          period_id: period.id,
          format: 'excel',
          report_type: 'comprehensive',
          include_departments: true,
          include_activities: true,
          include_processes: true
        }
      }
    end

    context "with valid parameters" do
      it "creates export job and returns job status" do
        expect {
          post "/api/v1/reports/export", params: valid_export_params, headers: auth_headers
        }.to change(JobStatus, :count).by(1)

        expect(response).to have_http_status(:accepted)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('job_id')
        expect(json_response).to have_key('status')
        expect(json_response['status']).to eq('pending')
      end
    end

    context "with invalid format" do
      let(:invalid_export_params) do
        valid_export_params.deep_merge(export: { format: 'invalid_format' })
      end

      it "returns validation error" do
        post "/api/v1/reports/export", params: invalid_export_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to include('format')
      end
    end
  end

  describe "GET /api/v1/reports/export/:job_id/status" do
    let(:job_status) { create(:job_status, hospital: hospital, job_type: 'report_export', status: 'completed') }

    context "with completed export job" do
      it "returns job status with download URL" do
        get "/api/v1/reports/export/#{job_status.job_id}/status", headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['job_id']).to eq(job_status.job_id)
        expect(json_response['status']).to eq('completed')
      end
    end
  end

  describe "GET /api/v1/reports/export/:job_id/download" do
    let(:job_status) { create(:job_status, hospital: hospital, job_type: 'report_export', status: 'completed') }

    before do
      # Create a dummy export file
      export_dir = Rails.root.join('tmp', 'exports')
      FileUtils.mkdir_p(export_dir)
      @export_file = export_dir.join("#{job_status.job_id}.xlsx")
      File.write(@export_file, "dummy excel content")
      
      job_status.update(result: { file_path: @export_file.to_s })
    end

    after do
      File.delete(@export_file) if File.exist?(@export_file)
    end

    context "with valid completed export job" do
      it "downloads the export file" do
        get "/api/v1/reports/export/#{job_status.job_id}/download", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to include('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        expect(response.headers['Content-Disposition']).to include('attachment')
      end
    end

    context "when export file does not exist" do
      before do
        File.delete(@export_file)
      end

      it "returns not found" do
        get "/api/v1/reports/export/#{job_status.job_id}/download", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end