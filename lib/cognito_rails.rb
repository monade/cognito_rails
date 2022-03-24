require 'active_support/concern'

Dir[File.expand_path('../cognito_rails/*.rb', __FILE__)].each { |f| require f }

module CognitoRails
  extend ActiveSupport::Concern
  
  def cognito_user
    @cognito_user ||= User.find(external_id)
  end

  def init_cognito_user
    return if external_id.present?

    cognito_user = User.new(email:)
    cognito_user.save!
    self.external_id = cognito_user.id
  end

  def destroy_cognito_user
    cognito_user&.destroy!
  end

  module Initializer
    def as_cognito_user
			send :include, CognitoRails
		end
	end
end
ActiveRecord::Base.send :extend, CognitoRails::Initializer