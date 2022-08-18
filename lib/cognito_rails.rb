require 'active_support/concern'

require 'jwt'
require 'open-uri'
require 'cognito_rails/config'
require 'cognito_rails/controller'
require 'cognito_rails/model'
require 'cognito_rails/user'
require 'cognito_rails/jwt'

module CognitoRails
  extend ActiveSupport::Concern

  module ModelInitializer
    def as_cognito_user(attribute_name: 'external_id')
      send :include, CognitoRails::Model
      self._cognito_attribute_name = attribute_name
    end
  end

  module ControllerInitializer
    def cognito_authentication(user_class: nil)
      send :include, CognitoRails::Controller
      self._cognito_user_class = user_class
    end
  end
end
ActiveRecord::Base.send :extend, CognitoRails::ModelInitializer
ActionController::Metal.send :extend, CognitoRails::ControllerInitializer
