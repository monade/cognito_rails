module CognitoRails::Controller
  extend ActiveSupport::Concern

  included do
    class_attribute :_cognito_user_class
  end

  def current_user
    @current_user ||= cognito_user_klass.find_by_cognito(external_cognito_id) if external_cognito_id
  end

  private

  def cognito_user_klass
    @cognito_user_klass ||= (self.class._cognito_user_class || CognitoRails::Config.default_user_class)&.constantize
  end

  def external_cognito_id
    token = request.headers['Authorization']&.split(' ')&.last

    return unless token

    CognitoRails::JWT.decode(token)&.dig(0, 'sub')
  end
end
