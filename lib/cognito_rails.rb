# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/dependencies/autoload'
require 'active_record'
require 'action_controller/metal'

# Provides a set of tools to integrate AWS Cognito in your Rails app
module CognitoRails
  extend ActiveSupport::Concern
  extend ActiveSupport::Autoload

  autoload :Config
  autoload :Controller
  autoload :Model
  autoload :User
  autoload :JWT
  autoload :PasswordGenerator

  # @private
  module ModelInitializer
    # @param attribute_name [String]
    # @return [void]
    def as_cognito_user(attribute_name: 'external_id')
      send :include, CognitoRails::Model
      self._cognito_attribute_name = attribute_name
    end
  end

  # @private
  module ControllerInitializer
    # @param user_class [Class,nil]
    # @return [void]
    def cognito_authentication(user_class: nil)
      send :include, CognitoRails::Controller
      self._cognito_user_class = user_class
    end

    def cognito_token_from(param: nil)
      send :include, CognitoRails::Controller
      self._cognito_read_token_from_param = param
    end
  end
end

# rubocop:disable Lint/SendWithMixinArgument
ActiveRecord::Base.send(:extend, CognitoRails::ModelInitializer)
ActionController::Metal.send(:extend, CognitoRails::ControllerInitializer)
# rubocop:enable Lint/SendWithMixinArgument
