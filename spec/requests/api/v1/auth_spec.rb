require 'rails_helper'

RSpec.describe "Api::V1::Auth", type: :request do
  let(:hospital) { create(:hospital) }
  let(:user) { create(:user, hospital: hospital, password: 'password123') }

  describe "POST /api/v1/auth/login" do
    let(:valid_credentials) do
      {
        user: {
          email: user.email,
          password: 'password123'
        }
      }
    end

    context "with valid credentials" do
      it "returns authentication token and user info" do
        post "/api/v1/auth/login", params: valid_credentials

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('token')
        expect(json_response).to have_key('user')
        expect(json_response['user']['id']).to eq(user.id)
        expect(json_response['user']['email']).to eq(user.email)
        expect(json_response['user']['hospital_id']).to eq(hospital.id)
      end
    end

    context "with invalid email" do
      let(:invalid_email_credentials) do
        {
          user: {
            email: 'nonexistent@example.com',
            password: 'password123'
          }
        }
      end

      it "returns unauthorized error" do
        post "/api/v1/auth/login", params: invalid_email_credentials

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid credentials')
      end
    end

    context "with invalid password" do
      let(:invalid_password_credentials) do
        {
          user: {
            email: user.email,
            password: 'wrongpassword'
          }
        }
      end

      it "returns unauthorized error" do
        post "/api/v1/auth/login", params: invalid_password_credentials

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid credentials')
      end
    end

    context "with inactive user" do
      before do
        user.update!(active: false)
      end

      it "returns forbidden error" do
        post "/api/v1/auth/login", params: valid_credentials

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Account is inactive')
      end
    end

    context "with inactive hospital" do
      before do
        hospital.update!(is_active: false)
      end

      it "returns forbidden error" do
        post "/api/v1/auth/login", params: valid_credentials

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Hospital is inactive')
      end
    end
  end

  describe "POST /api/v1/auth/logout" do
    let(:auth_headers) { { 'Authorization' => "Bearer #{user.generate_jwt_token}" } }

    before do
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    end

    it "successfully logs out user" do
      post "/api/v1/auth/logout", headers: auth_headers

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to include('Successfully logged out')
    end

    context "without authentication token" do
      it "returns unauthorized error" do
        allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_raise(StandardError.new("Unauthorized"))
        
        expect {
          post "/api/v1/auth/logout"
        }.to raise_error(StandardError, "Unauthorized")
      end
    end
  end

  describe "GET /api/v1/auth/me" do
    let(:auth_headers) { { 'Authorization' => "Bearer #{user.generate_jwt_token}" } }

    before do
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      allow_any_instance_of(ApplicationController).to receive(:current_hospital).and_return(hospital)
    end

    it "returns current user information" do
      get "/api/v1/auth/me", headers: auth_headers

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq(user.id)
      expect(json_response['email']).to eq(user.email)
      expect(json_response['first_name']).to eq(user.first_name)
      expect(json_response['last_name']).to eq(user.last_name)
      expect(json_response['role']).to eq(user.role)
      expect(json_response['hospital_id']).to eq(hospital.id)
      expect(json_response).to have_key('permissions')
    end

    context "without authentication token" do
      it "returns unauthorized error" do
        allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_raise(StandardError.new("Unauthorized"))
        
        expect {
          get "/api/v1/auth/me"
        }.to raise_error(StandardError, "Unauthorized")
      end
    end
  end

  describe "PUT /api/v1/auth/profile" do
    let(:auth_headers) { { 'Authorization' => "Bearer #{user.generate_jwt_token}" } }
    let(:update_params) do
      {
        user: {
          first_name: "Updated",
          last_name: "Name",
          phone: "555-0123"
        }
      }
    end

    before do
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    end

    it "updates user profile successfully" do
      put "/api/v1/auth/profile", params: update_params, headers: auth_headers

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['first_name']).to eq("Updated")
      expect(json_response['last_name']).to eq("Name")
      expect(json_response['phone']).to eq("555-0123")

      user.reload
      expect(user.first_name).to eq("Updated")
      expect(user.last_name).to eq("Name")
      expect(user.phone).to eq("555-0123")
    end

    context "with invalid data" do
      let(:invalid_params) do
        {
          user: {
            email: "invalid-email-format"
          }
        }
      end

      it "returns validation errors" do
        put "/api/v1/auth/profile", params: invalid_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to have_key('email')
      end
    end
  end

  describe "PUT /api/v1/auth/password" do
    let(:auth_headers) { { 'Authorization' => "Bearer #{user.generate_jwt_token}" } }
    let(:password_change_params) do
      {
        user: {
          current_password: 'password123',
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      }
    end

    before do
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    end

    it "changes password successfully" do
      put "/api/v1/auth/password", params: password_change_params, headers: auth_headers

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to include('Password changed successfully')

      # Verify password was actually changed
      user.reload
      expect(user.valid_password?('newpassword123')).to be true
      expect(user.valid_password?('password123')).to be false
    end

    context "with incorrect current password" do
      let(:wrong_current_password_params) do
        {
          user: {
            current_password: 'wrongpassword',
            password: 'newpassword123',
            password_confirmation: 'newpassword123'
          }
        }
      end

      it "returns validation error" do
        put "/api/v1/auth/password", params: wrong_current_password_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('current_password')
      end
    end

    context "with password confirmation mismatch" do
      let(:mismatch_confirmation_params) do
        {
          user: {
            current_password: 'password123',
            password: 'newpassword123',
            password_confirmation: 'differentpassword'
          }
        }
      end

      it "returns validation error" do
        put "/api/v1/auth/password", params: mismatch_confirmation_params, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('password_confirmation')
      end
    end
  end
end