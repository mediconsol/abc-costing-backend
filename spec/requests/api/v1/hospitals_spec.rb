require 'rails_helper'

RSpec.describe 'Api::V1::Hospitals', type: :request do
  let(:user) { create(:user) }
  let(:hospital) { create(:hospital) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{generate_jwt_token(user)}" } }

  before do
    # Associate user with hospital
    create(:hospital_user, user: user, hospital: hospital, role: 'admin')
  end

  describe 'GET /api/v1/hospitals' do
    let!(:hospitals) { create_list(:hospital, 3) }

    before do
      # Associate user with all hospitals
      hospitals.each do |hosp|
        create(:hospital_user, user: user, hospital: hosp, role: 'viewer')
      end
    end

    it 'returns list of user accessible hospitals' do
      get '/api/v1/hospitals', headers: auth_headers

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['success']).to be true
      expect(json_response['data']['hospitals'].size).to eq(4) # 3 created + 1 from let
    end

    it 'requires authentication' do
      get '/api/v1/hospitals'

      expect(response).to have_http_status(:unauthorized)
    end

    context 'with filters' do
      let!(:active_hospital) { create(:hospital, is_active: true) }
      let!(:inactive_hospital) { create(:hospital, is_active: false) }

      before do
        create(:hospital_user, user: user, hospital: active_hospital, role: 'viewer')
        create(:hospital_user, user: user, hospital: inactive_hospital, role: 'viewer')
      end

      it 'filters by active status' do
        get '/api/v1/hospitals', params: { active_only: 'true' }, headers: auth_headers

        json_response = JSON.parse(response.body)
        hospital_names = json_response['data']['hospitals'].map { |h| h['name'] }
        
        expect(hospital_names).to include(active_hospital.name)
        expect(hospital_names).not_to include(inactive_hospital.name)
      end
    end

    context 'with search' do
      let!(:searched_hospital) { create(:hospital, name: 'General Medical Center') }

      before do
        create(:hospital_user, user: user, hospital: searched_hospital, role: 'viewer')
      end

      it 'searches hospitals by name' do
        get '/api/v1/hospitals', params: { search: 'General' }, headers: auth_headers

        json_response = JSON.parse(response.body)
        expect(json_response['data']['hospitals'].size).to eq(1)
        expect(json_response['data']['hospitals'].first['name']).to include('General')
      end
    end
  end

  describe 'GET /api/v1/hospitals/:id' do
    it 'returns hospital details' do
      get "/api/v1/hospitals/#{hospital.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['success']).to be true
      expect(json_response['data']['hospital']['id']).to eq(hospital.id)
      expect(json_response['data']['hospital']['name']).to eq(hospital.name)
    end

    it 'returns 404 for non-existent hospital' do
      get '/api/v1/hospitals/non-existent-id', headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 403 for unauthorized access' do
      other_hospital = create(:hospital)
      
      get "/api/v1/hospitals/#{other_hospital.id}", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/hospitals' do
    let(:valid_params) do
      {
        hospital: {
          name: 'New Hospital',
          code: 'NH001',
          address: '123 Main St',
          phone: '+1-555-0123',
          email: 'admin@newhospital.com'
        }
      }
    end

    context 'when user is admin' do
      before do
        hospital.hospital_users.find_by(user: user).update!(role: 'admin')
      end

      it 'creates a new hospital successfully' do
        expect {
          post '/api/v1/hospitals', params: valid_params, headers: auth_headers
        }.to change(Hospital, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be true
        expect(json_response['data']['hospital']['name']).to eq('New Hospital')
      end

      it 'returns validation errors for invalid data' do
        invalid_params = valid_params.deep_dup
        invalid_params[:hospital][:name] = '' # Empty name

        post '/api/v1/hospitals', params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be false
        expect(json_response['errors']).to be_present
      end
    end

    context 'when user is not admin' do
      before do
        hospital.hospital_users.find_by(user: user).update!(role: 'viewer')
      end

      it 'returns forbidden status' do
        post '/api/v1/hospitals', params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /api/v1/hospitals/:id' do
    let(:update_params) do
      {
        hospital: {
          name: 'Updated Hospital Name',
          description: 'Updated description'
        }
      }
    end

    context 'when user is admin' do
      before do
        hospital.hospital_users.find_by(user: user).update!(role: 'admin')
      end

      it 'updates hospital successfully' do
        put "/api/v1/hospitals/#{hospital.id}", params: update_params, headers: auth_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['success']).to be true
        expect(json_response['data']['hospital']['name']).to eq('Updated Hospital Name')
        
        hospital.reload
        expect(hospital.name).to eq('Updated Hospital Name')
        expect(hospital.description).to eq('Updated description')
      end

      it 'returns validation errors for invalid data' do
        invalid_params = { hospital: { code: '' } } # Empty code

        put "/api/v1/hospitals/#{hospital.id}", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when user is not admin' do
      before do
        hospital.hospital_users.find_by(user: user).update!(role: 'manager')
      end

      it 'returns forbidden status' do
        put "/api/v1/hospitals/#{hospital.id}", params: update_params, headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/hospitals/:id' do
    context 'when user is admin' do
      before do
        hospital.hospital_users.find_by(user: user).update!(role: 'admin')
      end

      context 'when hospital can be deleted' do
        it 'deletes hospital successfully' do
          expect {
            delete "/api/v1/hospitals/#{hospital.id}", headers: auth_headers
          }.to change(Hospital, :count).by(-1)

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when hospital cannot be deleted' do
        before do
          create(:period, hospital: hospital) # Create dependent data
        end

        it 'returns unprocessable entity status' do
          delete "/api/v1/hospitals/#{hospital.id}", headers: auth_headers

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be false
        end
      end
    end

    context 'when user is not admin' do
      before do
        hospital.hospital_users.find_by(user: user).update!(role: 'manager')
      end

      it 'returns forbidden status' do
        delete "/api/v1/hospitals/#{hospital.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/hospitals/:id/summary' do
    let!(:period) { create(:period, :with_full_setup, hospital: hospital) }

    it 'returns hospital summary with statistics' do
      get "/api/v1/hospitals/#{hospital.id}/summary", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      
      expect(json_response['success']).to be true
      expect(json_response['data']).to include('summary')
      expect(json_response['data']['summary']).to include(
        'total_periods',
        'active_periods',
        'total_departments',
        'total_employees'
      )
    end
  end

  private

  def generate_jwt_token(user)
    # Mock JWT token generation
    # In real implementation, this would use Devise JWT
    "mock_jwt_token_for_user_#{user.id}"
  end
end