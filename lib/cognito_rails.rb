# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/dependencies/autoload'
require 'active_record'
require 'action_controller/metal'
require 'ostruct'

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
  autoload :Utils

  # @private
  module ModelInitializer
    # @param attribute_name [String]
    # @param user_pool_id [String]
    # @param aws_credentials [Hash,nil]
    # @return [void]
    def as_cognito_user(attribute_name: 'external_id', user_pool_id: nil, aws_credentials: nil)
      send :include, CognitoRails::Model
      self._cognito_attribute_name = attribute_name
      self._cognito_aws_user_pool_id = user_pool_id
      self._cognito_aws_client_credentials = aws_credentials

      credentials = (aws_credentials || {}).with_indifferent_access

      CognitoRails::Config.register_user_scope(
        self,
        {
          user_pool_id: user_pool_id,
          aws_region: credentials[:region],
          access_key_id: credentials[:access_key_id],
          secret_access_key: credentials[:secret_access_key]
        }
      )
    end
  end

  # @private
  module ControllerInitializer
    # @param user_class [Class,nil]
    # @param attribute_name [String,Symbol]
    # @return [void]
    def cognito_authentication(user_class: nil, attribute_name: :current_user)
      send :include, CognitoRails::Controller

      attribute = attribute_name.to_sym
      self._cognito_user_classes = _cognito_user_classes.merge(attribute => user_class)
      _cognito_define_user_reader(attribute)
    end
  end
end

ActiveRecord::Base.extend CognitoRails::ModelInitializer
ActionController::Metal.extend CognitoRails::ControllerInitializer
