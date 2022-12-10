# frozen_string_literal: true

module CognitoRails
  module Controller
    extend ActiveSupport::Concern

    # @scope class
    # @!attribute _cognito_user_class [rw]
    #   @return [String,nil] class name of user model

    included do
      class_attribute :_cognito_user_class
    end

    # @return [ActiveRecord::Base,nil]
    def current_user
      @current_user ||= cognito_user_klass.find_by_cognito(external_cognito_id) if external_cognito_id
    end

    private

    # @return [#find_by_cognito]
    def cognito_user_klass
      @cognito_user_klass ||= (self.class._cognito_user_class || CognitoRails::Config.default_user_class)&.constantize
    end

    # @return [String,nil] cognito user id
    def external_cognito_id
      # @type [String,nil]
      token = request.headers['Authorization']&.split(' ')&.last

      return unless token

      CognitoRails::JWT.decode(token)&.dig(0, 'sub')
    end
  end
end
