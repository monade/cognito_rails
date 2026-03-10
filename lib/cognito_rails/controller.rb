# frozen_string_literal: true

module CognitoRails
  module Controller
    extend ActiveSupport::Concern

    # @scope class
    # @!attribute _cognito_user_classes [rw]
    #   @return [Hash{Symbol => String,Class,nil}] user class by attribute

    included do
      class_attribute :_cognito_user_classes
      self._cognito_user_classes = {}
    end

    # @return [ActiveRecord::Base,nil]
    def current_user
      cognito_user_for(:current_user)
    end

    # @param attribute [Symbol]
    # @return [ActiveRecord::Base,nil]
    def cognito_user_for(attribute)
      attribute = attribute.to_sym
      return unless external_cognito_id(attribute)

      user_klass = cognito_user_klass(attribute)
      return unless user_klass

      ivar = "@#{attribute}"
      var = instance_variable_get(ivar)
      return var if var

      klass = user_klass.find_by_cognito(external_cognito_id(attribute))
      instance_variable_set(ivar, klass)
    end

    private

    # Get the useer from the specified attribute, or from the default :current_user if not found
    module ClassMethods
      # @param attribute [Symbol]
      # @return [void]
      def _cognito_define_user_reader(attribute)
        return if method_defined?(attribute)

        define_method(attribute) do
          cognito_user_for(attribute)
        end
      end
    end

    # @return [#find_by_cognito]
    def cognito_user_klass(attribute = :current_user)
      attribute = attribute.to_sym
      @cognito_user_klasses ||= {}
      @cognito_user_klasses[attribute] ||= begin
        user_class = self.class._cognito_user_classes[attribute]
        user_class ||= CognitoRails::Config.default_user_class
        resolve_user_class(user_class)
      end
    end

    # @param user_class [String,Symbol,Class,nil]
    # @return [Class,nil]
    def resolve_user_class(user_class)
      case user_class
      when nil
        nil
      when String, Symbol
        user_class.to_s.constantize
      else
        user_class
      end
    end

    # @return [String,nil] cognito user id
    def external_cognito_id(attribute = :current_user)
      # @type [String,nil]
      token = request.headers['Authorization']&.split(' ')&.last

      return unless token

      user_class = cognito_user_klass(attribute)
      user_pool_id = user_class&._cognito_aws_user_pool_id || CognitoRails::Config.aws_user_pool_id
      aws_region = CognitoRails::User.cognito_region_for(user_class)
      jwt_payload = CognitoRails::JWT.decode(token, user_pool_id: user_pool_id, aws_region: aws_region)
      jwt_payload&.dig(0, 'sub')
    end
  end
end
