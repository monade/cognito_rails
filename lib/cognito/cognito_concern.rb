module CognitoConcern
  extend ActiveSupport::Concern

  def current_user
    @current_user ||= User.find_by(external_id: request.headers['x-auth-id']) if request.headers['x-auth-id']
  end
end