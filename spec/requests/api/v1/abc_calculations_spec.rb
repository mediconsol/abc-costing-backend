require 'rails_helper'

RSpec.describe "Api::V1::AbcCalculations", type: :request do
  let(:hospital) { create(:hospital) }
  let(:user) { create(:user, hospital: hospital) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{user.generate_jwt_token}" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_hospital).and_return(hospital)
  end

  describe "POST /api/v1/abc_calculations" do
    let(:period) { create(:period, hospital: hospital) }
    let(:valid_params) do
      {
        abc_calculation: {
          period_id: period.id,
          name: "ABC Calculation Test",
          description: "Test calculation description"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new ABC calculation and returns job status" do
        expect {
          post "/api/v1/abc_calculations", params: valid_params, headers: auth_headers
        }.to change(JobStatus, :count).by(1)

        expect(response).to have_http_status(:accepted)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('job_id')
        expect(json_response).to have_key('status')
        expect(json_response['status']).to eq('pending')
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          abc_calculation: {
            period_id: nil,
            name: "",
            description: "Test calculation description"
          }
        }
      end

      it "returns validation errors" do
        post "/api/v1/abc_calculations", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_raise(StandardError.new("Unauthorized"))
        
        expect {
          post "/api/v1/abc_calculations", params: valid_params
        }.to raise_error(StandardError, "Unauthorized")
      end
    end
  end

  describe "GET /api/v1/abc_calculations/:job_id/status" do
    let(:job_status) { create(:job_status, hospital: hospital, status: 'in_progress', progress: 50) }

    context "with valid job ID" do
      it "returns job status information" do
        get "/api/v1/abc_calculations/#{job_status.job_id}/status", headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['job_id']).to eq(job_status.job_id)
        expect(json_response['status']).to eq('in_progress')
        expect(json_response['progress']).to eq(50)
      end
    end

    context "with non-existent job ID" do
      it "returns not found" do
        get "/api/v1/abc_calculations/non-existent-id/status", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/abc_calculations/:job_id/results" do
    let(:job_status) { create(:job_status, hospital: hospital, status: 'completed') }
    let(:period) { create(:period, hospital: hospital) }

    before do
      # Create some test data for results
      department = create(:department, hospital: hospital)
      account = create(:account, hospital: hospital, period: period, department: department)
      create(:cost_input, account: account, amount: 100000)
      
      activity = create(:activity, hospital: hospital, department: department)
      create(:activity_cost, activity: activity, period: period, allocated_cost: 50000)
      
      process = create(:process, hospital: hospital)
      create(:process_cost_assignment, process: process, period: period, assigned_cost: 30000)
    end

    context "when calculation is completed" do
      it "returns calculation results" do
        get "/api/v1/abc_calculations/#{job_status.job_id}/results", headers: auth_headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('period_id')
        expect(json_response).to have_key('departments')
        expect(json_response).to have_key('activities')
        expect(json_response).to have_key('processes')
        expect(json_response).to have_key('summary')
      end
    end

    context "when calculation is not completed" do
      let(:job_status) { create(:job_status, hospital: hospital, status: 'in_progress') }

      it "returns bad request" do
        get "/api/v1/abc_calculations/#{job_status.job_id}/results", headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not completed')
      end
    end
  end
end