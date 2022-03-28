require 'active_support/concern'

require 'cognito_rails/config'
require 'cognito_rails/controller_concern'
require 'cognito_rails/user'

module CognitoRails
  extend ActiveSupport::Concern

  module Initializer
    def as_cognito_user
      send :include, CognitoRails
    end
  end

  included do
    class_attribute :_cognito_verify_email
    class_attribute :_cognito_verify_phone
    class_attribute :_cognito_attributes
    self._cognito_attributes = Array.new
    
    before_create do
      self.init_cognito_user
    end
  
    after_destroy do
      self.destroy_cognito_user
    end
  end
  
  def cognito_user
    @cognito_user ||= User.find(external_id, user_class: self.class)
  end

  protected

  def init_cognito_user
    return if external_id.present?

    attrs = { email: , user_class: self.class }
    attrs[:phone] = phone if respond_to?(:phone)
    cognito_user = User.new(attrs)
    cognito_user.save!
    self.external_id = cognito_user.id
  end

  def destroy_cognito_user
    cognito_user&.destroy!
  end

  module ClassMethods
    def cognito_verify_email
      self._cognito_verify_email = true
    end

    def cognito_verify_phone
      self._cognito_verify_phone = true
    end

    def define_cognito_attribute(name, value)
      self._cognito_attributes << { name: "custom:#{name}", value: value }
    end

  end
end
ActiveRecord::Base.send :extend, CognitoRails::Initializer