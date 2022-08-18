require 'active_support'
require 'rails'
require 'rspec'
require 'active_record'
require 'action_controller'
require 'cognito_rails'
require 'factory_bot_rails'
require 'rspec/collection_matchers'
require 'factories/user'

I18n.enforce_available_locales = false
RSpec::Expectations.configuration.warn_about_potential_false_positives = false

Dir[File.expand_path('../support/*.rb', __FILE__)].each { |f| require f }

CognitoRails::Config.aws_access_key_id = 'access_key_id'
CognitoRails::Config.aws_region = 'region'
CognitoRails::Config.aws_secret_access_key = 'secret_access_key'
CognitoRails::Config.aws_user_pool_id = 'user_pool_id'
CognitoRails::Config.default_user_class = 'User'

RSpec.configure do |config|

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    Schema.create
  end

  config.around(:each) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
