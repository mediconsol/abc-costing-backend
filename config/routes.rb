Rails.application.routes.draw do
  devise_for :users
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  
  # API 라우팅
  namespace :api do
    namespace :v1 do
      # 병원 및 기간 관리
      resources :hospitals do
        resources :periods
        
        # 병원별 기간 스코프 라우팅
        resources :periods do
          member do
            patch :activate
          end
          
          # 기초정보 관리
          resources :departments
          resources :accounts
          resources :activities
          resources :processes
          resources :revenue_codes
          resources :drivers
          
          # 데이터 입력
          resources :employees
          resources :work_ratios
          resources :cost_inputs
          resources :revenue_inputs
          
          # 매핑 관리
          resources :account_activity_mappings, path: 'mappings/account_activity'
          resources :activity_process_mappings, path: 'mappings/activity_process'
          resources :driver_allocations
          
          # 원가계산 실행
          post 'allocations/execute', to: 'allocations#execute'
          get 'allocations/status/:job_id', to: 'allocations#status'
          get 'allocations/results', to: 'allocations#results'
          
          # 백그라운드 작업 관리
          resources :jobs, only: [:index, :show] do
            member do
              delete :cancel
            end
            collection do
              get :summary
            end
          end
          
          # 리포트
          namespace :reports do
            # 부서별 리포트
            resources :departments, only: [:index, :show] do
              collection do
                get :cost_analysis
                get :hierarchy
              end
            end
            
            # 활동별 리포트
            resources :activities, only: [:index, :show] do
              collection do
                get :cost_distribution
                get :efficiency
                get :performance
              end
            end
            
            # KPI 리포트
            get 'kpi', to: 'kpi#index'
            get 'kpi/financial', to: 'kpi#financial'
            get 'kpi/operational', to: 'kpi#operational'
            get 'kpi/dashboard', to: 'kpi#dashboard'
            
            # 내보내기 기능
            post 'export', to: 'export#create'
            get 'export/templates', to: 'export#templates'
            get 'export/history', to: 'export#history'
            get 'export/:job_id/download', to: 'export#download'
            delete 'export/:job_id', to: 'export#destroy'
            get 'export/quick/:type', to: 'export#quick_export'
          end
        end
      end
      
      # 인증 관련
      post 'auth/login', to: 'auth#login'
      post 'auth/signup', to: 'auth#signup'
      delete 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
    end
  end
  
  # Root path
  root to: proc { [200, {}, ['ABC Costing Backend API']] }
end
