# This file is copied to spec/ when you run 'rails generate rspec:install'

# Normally loaded via application config; I want the production code to
# choke when app_id and app_secret is not set.
ENV["RAILS_ENV"] ||= 'test'
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
  SimpleCov.command_name "spec"
end

if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!('rails')
end

require 'figaro' # must declare before the application loads
require 'engine_cart'
require 'omniauth-orcid'
require File.expand_path("../../.internal_test_app/config/environment.rb",  __FILE__)

EngineCart.load_application!

require 'orcid/spec_support'
require 'rspec/rails'
require 'rspec/autorun'
require 'rspec/given'
require 'rspec/active_model/mocks'
require 'rspec/its'
require 'database_cleaner'
require 'factory_girl'
require 'rspec-html-matchers'
require 'webmock/rspec'
require 'capybara'
require 'capybara-webkit'
require 'headless'

Capybara.register_driver :webkit do |app|
  Capybara::Webkit::Driver.new(app, :ignore_ssl_errors => true)
end

Capybara.javascript_driver = :webkit

if ENV['TRAVIS'] || ENV['JENKINS']
  headless = Headless.new
  headless.start
end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path("../support/**/*.rb",__FILE__)].each {|f| require f}
Dir[File.expand_path("../factories/**/*.rb",__FILE__)].each {|f| require f}

# From https://github.com/plataformatec/devise/wiki/How-To:-Stub-authentication-in-controller-specs
module ControllerHelpers
  def sign_in(user = double('user'))
    if user.nil?
      request.env['warden'].stub(:authenticate!).
        and_throw(:warden, {:scope => :user})
      controller.stub :current_user => nil
    else
      request.env['warden'].stub :authenticate! => user
      controller.stub :current_user => user
    end
  end

  def main_app
    controller.main_app
  end

  def orcid
    controller.orcid
  end

end

module FixtureFiles
  def fixture_file(path)
    Pathname.new(File.expand_path(File.join("../fixtures", path), __FILE__))
  end
end

RSpec.configure do |config|
  config.include Devise::TestHelpers, type: :controller
  config.include ControllerHelpers, type: :controller
  config.include FixtureFiles
  config.include RSpecHtmlMatchers

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  config.infer_spec_type_from_file_location!

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
  end
  config.before(:each) do
    OmniAuth.config.test_mode = true
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
  end
end
