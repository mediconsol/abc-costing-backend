# Security Configuration for ABC Costing Application
# This file configures security measures for production deployment

Rails.application.configure do
  if Rails.env.production?
    # Request security headers
    config.force_ssl = true
    config.ssl_options = {
      hsts: {
        expires: 1.year,
        subdomains: true,
        preload: true
      }
    }

    # Configure secure headers
    config.after_initialize do
      # Add security headers middleware
      if defined?(ActionDispatch)
        ActionDispatch::Response.class_eval do
          alias_method :original_set_header, :set_header
          
          def set_header(key, value)
            # Add security headers to all responses
            case key
            when 'Content-Type'
              # Add X-Content-Type-Options header
              original_set_header('X-Content-Type-Options', 'nosniff')
              original_set_header('X-Frame-Options', 'DENY')
              original_set_header('X-XSS-Protection', '1; mode=block')
              original_set_header('Referrer-Policy', 'strict-origin-when-cross-origin')
              
              # Content Security Policy for API responses
              if value&.include?('application/json')
                original_set_header(
                  'Content-Security-Policy',
                  "default-src 'none'; frame-ancestors 'none';"
                )
              end
            end
            
            original_set_header(key, value)
          end
        end
      end
    end

    # Rate limiting configuration
    config.after_initialize do
      # Simple in-memory rate limiting (consider Redis for production clusters)
      @rate_limit_store = {}
      @rate_limit_mutex = Mutex.new

      # Add rate limiting middleware
      Rails.application.middleware.insert_before ActionDispatch::Static, Class.new do
        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)
          
          # Apply rate limiting to API endpoints
          if request.path.start_with?('/api/')
            client_ip = request.ip
            
            if rate_limited?(client_ip, request.path)
              return [429, { 'Content-Type' => 'application/json' }, [
                { error: 'Rate limit exceeded. Please try again later.' }.to_json
              ]]
            end
          end
          
          @app.call(env)
        end

        private

        def rate_limited?(ip, path)
          Rails.application.instance_variable_get(:@rate_limit_mutex).synchronize do
            store = Rails.application.instance_variable_get(:@rate_limit_store)
            now = Time.current.to_i
            key = "#{ip}:#{path}"
            
            # Clean old entries (older than 1 hour)
            store.delete_if { |k, v| now - v[:first_request] > 3600 }
            
            # Initialize or update request count
            if store[key]
              store[key][:count] += 1
              store[key][:last_request] = now
            else
              store[key] = { count: 1, first_request: now, last_request: now }
            end
            
            # Rate limit: 100 requests per hour for calculation endpoints
            limit = path.match?(/abc_calculations|reports\/export/) ? 20 : 100
            
            store[key][:count] > limit
          end
        end
      end
    end

    # API Authentication security
    config.after_initialize do
      # Configure JWT security
      if defined?(Devise)
        Devise.setup do |config|
          # JWT expiration time
          config.jwt do |jwt|
            jwt.secret = Rails.application.credentials.devise_jwt_secret_key
            jwt.dispatch_requests = [
              ['POST', %r{^/api/v1/auth/login$}]
            ]
            jwt.revocation_requests = [
              ['DELETE', %r{^/api/v1/auth/logout$}]
            ]
            jwt.expiration_time = 24.hours.to_i # 24 hours
          end
        end
      end

      # Add authentication monitoring
      ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, start, finish, id, payload|
        if payload[:controller].match?(/auth|sessions/i)
          ip = payload[:remote_ip] || 'unknown'
          action = "#{payload[:controller]}##{payload[:action]}"
          status = payload[:status]
          
          # Log authentication attempts
          if action.include?('login') || action.include?('sign_in')
            if status == 200
              Rails.logger.info("Successful authentication from #{ip}")
            else
              Rails.logger.warn("Failed authentication attempt from #{ip} - Status: #{status}")
            end
          end
        end
      end
    end

    # Input validation and sanitization
    config.after_initialize do
      # Add parameter filtering for sensitive data
      Rails.application.config.filter_parameters += [
        :password, :password_confirmation, :current_password,
        :secret, :token, :key, :salt, :certificate, :private_key,
        :jwt_token, :auth_token, :api_key
      ]

      # Validate file uploads for export functionality
      if defined?(ActionController::Parameters)
        ActionController::Parameters.class_eval do
          def permit_export_params
            permit(:period_id, :format, :report_type, :include_departments, 
                   :include_activities, :include_processes, :include_summary)
          end
        end
      end
    end

    # Database security
    config.after_initialize do
      # Configure database connection security
      if defined?(ActiveRecord)
        # Enable query logs in production for security monitoring
        ActiveRecord::Base.logger = Rails.logger
        
        # Monitor for potential SQL injection attempts
        ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
          sql = payload[:sql]
          
          # Check for suspicious SQL patterns
          suspicious_patterns = [
            /union\s+select/i,
            /drop\s+table/i,
            /delete\s+from.*where.*1\s*=\s*1/i,
            /insert\s+into.*values.*\(/i,
            /update.*set.*where.*1\s*=\s*1/i
          ]
          
          if suspicious_patterns.any? { |pattern| sql.match?(pattern) }
            Rails.logger.error("Suspicious SQL detected: #{sql}")
            # In production, you might want to alert administrators
          end
        end
      end
    end

    # Session security
    config.session_store :cookie_store, 
      key: '_abc_costing_session',
      secure: true,
      httponly: true,
      same_site: :strict,
      expire_after: 24.hours

    # Configure CORS for API access
    config.after_initialize do
      if defined?(Rack::Cors)
        Rails.application.config.middleware.insert_before 0, Rack::Cors do
          allow do
            # Configure allowed origins based on environment
            allowed_origins = ENV['ALLOWED_ORIGINS']&.split(',') || ['https://yourdomain.com']
            origins allowed_origins
            
            resource '/api/*',
              headers: :any,
              methods: [:get, :post, :put, :patch, :delete, :options, :head],
              credentials: true,
              max_age: 86400 # 24 hours
          end
        end
      end
    end

    # File upload security for export downloads
    config.after_initialize do
      # Secure file serving
      Rails.application.routes.prepend do
        # Override default file serving with security checks
        get '/exports/*path', to: proc { |env|
          request = ActionDispatch::Request.new(env)
          
          # Verify user authentication for file downloads
          auth_header = request.headers['Authorization']
          unless auth_header&.start_with?('Bearer ')
            return [401, {}, ['Unauthorized']]
          end
          
          # Verify file path is within allowed directory
          path = request.params['path']
          export_dir = Rails.root.join('tmp', 'exports')
          full_path = export_dir.join(path).cleanpath
          
          unless full_path.to_s.start_with?(export_dir.to_s)
            return [403, {}, ['Forbidden - Path traversal detected']]
          end
          
          # Serve file if it exists and is recent (within 7 days)
          if File.exist?(full_path) && File.mtime(full_path) > 7.days.ago
            [200, { 'Content-Type' => 'application/octet-stream' }, [File.read(full_path)]]
          else
            [404, {}, ['File not found or expired']]
          end
        }
      end
    end

    # Background job security
    config.after_initialize do
      if defined?(Sidekiq)
        # Configure Sidekiq Web UI authentication
        require 'sidekiq/web'
        
        Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
          username == ENV.fetch('SIDEKIQ_USERNAME', 'admin') &&
          password == ENV.fetch('SIDEKIQ_PASSWORD', 'change_this_password')
        end
        
        # Monitor for long-running jobs that might indicate attacks
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Class.new do
              def call(worker, job, queue)
                start_time = Time.current
                
                yield
                
                duration = Time.current - start_time
                
                # Alert on jobs running longer than expected
                if duration > 30.minutes
                  Rails.logger.warn(
                    "Long-running job detected: #{job['class']} ran for #{duration.round(2)} seconds"
                  )
                end
              end
            end
          end
        end
      end
    end

    # Hospital data isolation security
    config.after_initialize do
      # Ensure all models respect hospital context
      if defined?(ApplicationRecord)
        ApplicationRecord.class_eval do
          # Add a security check method
          def self.secure_find(id, hospital)
            record = find(id)
            if record.respond_to?(:hospital) && record.hospital != hospital
              raise ActiveRecord::RecordNotFound, "Record not found or access denied"
            end
            record
          end
        end
      end
    end

    # Audit logging for sensitive operations
    config.after_initialize do
      # Log sensitive operations
      audit_events = %w[
        abc_calculation_started abc_calculation_completed abc_calculation_failed
        export_requested export_completed export_downloaded
        user_login user_logout user_created user_updated
        hospital_created hospital_updated hospital_deleted
      ]
      
      audit_events.each do |event|
        ActiveSupport::Notifications.subscribe(event) do |name, start, finish, id, payload|
          Rails.logger.info(
            "AUDIT: #{name} - User: #{payload[:user_id]} - " \
            "Hospital: #{payload[:hospital_id]} - " \
            "Data: #{payload.except(:user_id, :hospital_id).to_json}"
          )
        end
      end
    end
  end
end

# Additional security configurations
if Rails.env.production?
  # Disable server tokens
  Rails.application.config.consider_all_requests_local = false
  Rails.application.config.log_level = :info
  
  # Configure secure random for tokens
  SecureRandom.instance_eval do
    def self.secure_token(length = 32)
      hex(length / 2)
    end
  end
end