source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.2.2'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 2.5'
gem 'pg'

# Use Puma as the app server
gem 'puma', '>= 5.0'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 5.0'

# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# jwt for token based auth
gem 'jwt'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  gem 'rspec-rails'
  gem 'rails-controller-testing'

  # Capybara for feature/integration tests
  gem 'capybara'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'selenium-webdriver'

  gem 'webdrivers'

  # Rubocop is a static code analyzer to enforce style.
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-capybara', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rspec_rails', require: false

  gem 'simplecov'
  gem 'timecop'
  gem 'webmock'
  gem 'i18n-tasks'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem 'bootstrap_form'
gem 'cancancan'
gem 'config'
gem 'devise'
gem 'devise-bootstrap-views', '~> 1.0'
gem 'devise_invitable', '~> 2.0.0'
gem 'friendly_id'
gem 'honeybadger'
gem 'http'
gem 'kaminari'
gem 'okcomputer'
gem 'paper_trail'
gem 'rolify'
gem 'sidekiq', '~> 7.0'
gem 'inline_svg'
gem 'marc'
gem 'rexml' # see https://github.com/ruby-marc/ruby-marc/issues/67...
gem 'whenever'

gem 'rack-attack'

gem 'ahoy_matey'
gem 'groupdate'

gem 'activejob-status'

group :deployment do
  gem 'capistrano', '~> 3.0'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-passenger'
  gem 'capistrano-shared_configs'
  gem 'dlss-capistrano'
end
gem 'concurrent-ruby'

gem "local_time", "~> 2.1"

gem "cssbundling-rails", "~> 1.1"

gem "importmap-rails", "~> 1.1"

gem "turbo-rails", "~> 2.0"
