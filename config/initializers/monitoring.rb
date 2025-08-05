# Monitoring and Performance Configuration
# This file configures monitoring, logging, and performance optimization for the ABC Costing application

Rails.application.configure do
  # Performance monitoring
  if Rails.env.production?
    # Memory profiling for large ABC calculations
    config.after_initialize do
      # Configure memory monitoring for background jobs
      if defined?(Sidekiq)
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            # Add memory monitoring middleware
            chain.add Class.new do
              def call(worker, job, queue)
                memory_before = get_memory_usage
                start_time = Time.current

                yield

                memory_after = get_memory_usage
                duration = Time.current - start_time
                memory_diff = memory_after - memory_before

                # Log memory usage for ABC calculation jobs
                if job['class'].include?('AbcCalculation') || job['class'].include?('ReportGeneration')
                  Rails.logger.info(
                    "Job #{job['class']} completed in #{duration.round(2)}s, " \
                    "memory: #{memory_before}MB -> #{memory_after}MB (#{memory_diff >= 0 ? '+' : ''}#{memory_diff}MB)"
                  )
                  
                  # Alert if memory usage is too high
                  if memory_after > 500 # 500MB threshold
                    Rails.logger.warn("High memory usage detected: #{memory_after}MB for job #{job['class']}")
                  end
                end
              end

              private

              def get_memory_usage
                return 0 unless File.exist?('/proc/self/status')
                
                File.read('/proc/self/status').match(/VmRSS:\s+(\d+)/)[1].to_i / 1024
              rescue
                0
              end
            end
          end
        end
      end
    end

    # Database query monitoring
    config.after_initialize do
      if defined?(ActiveRecord)
        ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
          duration = (finish - start) * 1000
          
          # Log slow queries (> 500ms)
          if duration > 500
            Rails.logger.warn(
              "Slow query detected: #{duration.round(2)}ms - #{payload[:sql]}"
            )
          end
          
          # Log ABC-related queries for optimization
          if payload[:sql].match?(/(accounts|activities|processes|cost_inputs|activity_costs|process_cost_assignments)/i)
            if duration > 100 # Log ABC queries > 100ms
              Rails.logger.info(
                "ABC Query: #{duration.round(2)}ms - #{payload[:sql].truncate(100)}"
              )
            end
          end
        end
      end
    end

    # Background job monitoring
    config.after_initialize do
      if defined?(Sidekiq)
        # Monitor job queue sizes
        Thread.new do
          loop do
            begin
              stats = Sidekiq::Stats.new
              
              # Alert if queue size is too large
              if stats.enqueued > 100
                Rails.logger.warn("High queue size detected: #{stats.enqueued} jobs enqueued")
              end
              
              # Alert if there are failed jobs
              if stats.failed > 0
                Rails.logger.error("Failed jobs detected: #{stats.failed} failed jobs")
              end
              
              # Log job statistics every 5 minutes
              Rails.logger.info(
                "Sidekiq Stats - Enqueued: #{stats.enqueued}, " \
                "Failed: #{stats.failed}, " \
                "Processed: #{stats.processed}, " \
                "Busy: #{stats.workers_size}"
              )
              
              sleep 300 # 5 minutes
            rescue => e
              Rails.logger.error("Error monitoring Sidekiq stats: #{e.message}")
              sleep 300
            end
          end
        end
      end
    end
  end

  # Request monitoring for API endpoints
  config.after_initialize do
    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, start, finish, id, payload|
      duration = (finish - start) * 1000
      
      # Log slow API requests (> 2 seconds)
      if duration > 2000
        Rails.logger.warn(
          "Slow API request: #{payload[:controller]}##{payload[:action]} " \
          "took #{duration.round(2)}ms with params: #{payload[:params].except('password', 'password_confirmation')}"
        )
      end
      
      # Log ABC calculation requests
      if payload[:controller].match?(/abc_calculations|reports|allocations/i)
        Rails.logger.info(
          "ABC API: #{payload[:controller]}##{payload[:action]} " \
          "completed in #{duration.round(2)}ms " \
          "with status #{payload[:status]}"
        )
      end
    end
  end

  # Health check monitoring
  config.after_initialize do
    # Create a simple health check endpoint monitoring
    if Rails.env.production?
      Thread.new do
        loop do
          begin
            # Check database connectivity
            ActiveRecord::Base.connection.execute('SELECT 1')
            
            # Check Redis connectivity if Sidekiq is configured
            if defined?(Sidekiq)
              Sidekiq.redis { |conn| conn.ping }
            end
            
            Rails.logger.debug("Health check passed - Database and Redis are accessible")
            
            sleep 60 # Check every minute
          rescue => e
            Rails.logger.error("Health check failed: #{e.message}")
            sleep 60
          end
        end
      end
    end
  end

  # ABC-specific performance optimizations
  config.after_initialize do
    # Note: Database pool size is configured in database.yml
    # Connection pool optimization happens at the database adapter level
    
    # Configure Sidekiq for ABC workloads
    if defined?(Sidekiq) && Rails.env.production?
      Sidekiq.configure_server do |config|
        # Increase concurrency for ABC calculations
        config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 10).to_i
        
        # Configure specific queues for ABC operations
        config.queues = {
          'critical' => 3,    # High priority ABC calculations
          'default' => 2,     # Regular operations
          'reports' => 1      # Report generation
        }
      end
    end
  end

  # Custom metrics collection
  config.after_initialize do
    if Rails.env.production?
      # Collect ABC-specific metrics
      Thread.new do
        loop do
          begin
            hospital_count = Hospital.active.count
            active_calculations = JobStatus.where(status: ['pending', 'in_progress'], job_type: 'abc_calculation').count
            active_exports = JobStatus.where(status: ['pending', 'in_progress'], job_type: 'report_export').count
            
            Rails.logger.info(
              "ABC Metrics - Hospitals: #{hospital_count}, " \
              "Active Calculations: #{active_calculations}, " \
              "Active Exports: #{active_exports}"
            )
            
            # Custom business metrics
            today_calculations = JobStatus.where(
              job_type: 'abc_calculation',
              created_at: Date.current.beginning_of_day..Date.current.end_of_day
            ).count
            
            Rails.logger.info("Daily ABC Calculations: #{today_calculations}")
            
            sleep 600 # Every 10 minutes
          rescue => e
            Rails.logger.error("Error collecting ABC metrics: #{e.message}")
            sleep 600
          end
        end
      end
    end
  end

  # Error tracking and alerting
  config.after_initialize do
    # Subscribe to exceptions in production
    if Rails.env.production?
      ActiveSupport::Notifications.subscribe('exception') do |name, start, finish, id, payload|
        exception = payload[:exception_object]
        
        # Special handling for ABC-related errors
        if exception.backtrace&.any? { |line| line.match?(/abc_calculation|activity_cost|process_cost/i) }
          Rails.logger.error(
            "ABC System Error: #{exception.class} - #{exception.message}\n" \
            "Backtrace: #{exception.backtrace.first(5).join("\n")}"
          )
          
          # You could integrate with external error tracking services here
          # Example: Sentry.capture_exception(exception) if defined?(Sentry)
        end
      end
    end
  end
end

# Configure log rotation for production
if Rails.env.production?
  # Ensure log directory exists
  log_dir = Rails.root.join('log')
  FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
  
  # Custom log formatting for better parsing
  class CustomLogFormatter < Logger::Formatter
    def call(severity, time, progname, msg)
      "[#{time.iso8601}] #{severity.ljust(5)} #{progname}: #{msg}\n"
    end
  end
  
  # Apply custom formatter
  Rails.logger.formatter = CustomLogFormatter.new if Rails.logger.respond_to?(:formatter=)
end