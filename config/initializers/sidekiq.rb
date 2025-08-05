Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    network_timeout: 5
  }
  
  # Configure queues
  config.queues = [
    ['critical', 10],
    ['high', 8], 
    ['default', 5],
    ['low', 2],
    ['abc_calculations', 6],
    ['reports', 3]
  ]
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    network_timeout: 5
  }
end

# Configure job retry settings
Sidekiq.default_job_options = {
  'backtrace' => true,
  'retry' => 3
}

# Sidekiq Web UI authentication (if needed)
if Rails.env.production?
  require 'sidekiq/web'
  Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
    [user, password] == [ENV['SIDEKIQ_USERNAME'], ENV['SIDEKIQ_PASSWORD']]
  end
end