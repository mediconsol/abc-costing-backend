source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# Use postgresql as the database for Active Record (production)
gem "pg", "~> 1.1", group: :production
# Use SQLite3 for development and test
gem "sqlite3", ">= 2.1", group: [:development, :test]
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# Authentication and Authorization
gem "devise"
# gem "devise-jwt"  # Railway 배포를 위해 임시 비활성화
gem "pundit"

# Background Jobs
gem "sidekiq"
gem "redis"

# API and Serialization
gem "fast_jsonapi"
gem "kaminari"  # Pagination
gem "ransack"   # Search and filtering

# UUID support
gem "uuid"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  
  # Testing framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  
  # Database tools
  gem "database_cleaner-active_record"
end

group :development do
  # Live reload for development
  gem "spring"
  gem "spring-watcher-listen"
  
  # Better error pages
  gem "better_errors"
  gem "binding_of_caller"
end
