source 'https://rubygems.org'

# Specify your gem's dependencies in rabl.gemspec
gemspec

gem 'i18n', '>= 0.6'

group :test do
  gem 'rack-test', :require => 'rack/test'
  gem 'activerecord', '>= 4.0', :require => 'active_record'
  gem 'sqlite3', '>= 1.5'
  gem 'hashie'
end

group :development, :test do
  gem 'oj'
  gem 'rake'
  gem 'riot'
  gem 'rr'
  gem 'tilt'
end
