# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.3'

gem 'aws-sdk-s3', require: false
gem 'bcrypt'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'cssbundling-rails', '>= 0.1.0'
gem 'honeybadger', '~> 4.11'
gem 'image_processing', '~> 1.12'
gem 'jbuilder', '~> 2.11'
gem 'jsbundling-rails', '~> 1.0.2'
gem 'meta-tags'
gem 'pg'
gem 'puma', '~> 5.6'
gem 'rails', '~> 7.0.1'
gem 'redis', '~> 4.0'
gem 'rqrcode', '~> 2.1'
gem 'rubyzip'
gem 'sprockets-rails'
gem 'stimulus-rails', '>= 0.4.0'
gem 'turbo-rails', '>= 1.0.0'

group :development, :test do
  gem 'byebug'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails'
end

group :development do
  gem 'better_html'
  gem 'erb_lint', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'web-console', '>= 4.1.0'
end

group :test do
  gem 'capybara', '>= 3.26'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers', '~> 5.1'
  gem 'webdrivers'
end
