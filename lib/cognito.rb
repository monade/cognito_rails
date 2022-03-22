require 'active_support/concern'
require 'cognito/cognito_concern'
require 'cognito/cognito_user'

module Cognito
  extend ActiveSupport::Concern
  
  def cognito_user
    @cognito_user ||= CognitoUser.find(external_id)
  end

  def init_cognito_user
    return if external_id.present?

    cognito_user = CognitoUser.new(email:)
    cognito_user.save!
    self.external_id = cognito_user.id
  end

  def destroy_cognito_user
    cognito_user&.destroy!
  end

  module Initializer
    def as_cognito_user
			send :include, Cognito
		end
	end
end
ActiveRecord::Base.send :extend, Cognito::Initializer