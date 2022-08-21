require 'active_support/concern'

module CognitoRails
  extend ActiveSupport::Concern
  extend ActiveSupport::Autoload

  autoload :Config
  autoload :Controller
  autoload :Model
  autoload :User
  autoload :JWT

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
