module CognitoRails
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :_cognito_verify_email
      class_attribute :_cognito_verify_phone
      class_attribute :_cognito_custom_attributes
      class_attribute :_cognito_attribute_name
      self._cognito_custom_attributes = []

      before_create do
        self.init_cognito_user unless CognitoRails::Config.skip_model_hooks
      end

      after_destroy do
        self.destroy_cognito_user unless CognitoRails::Config.skip_model_hooks
      end
    end

    def cognito_external_id
      self[self.class._cognito_attribute_name]
    end

    def cognito_external_id=(value)
      self[self.class._cognito_attribute_name] = value
    end

    def cognito_user
      @cognito_user ||= User.find(cognito_external_id, user_class: self.class)
    end

    protected

    def init_cognito_user
      return if cognito_external_id.present?

      attrs = { email: email, user_class: self.class }
      attrs[:phone] = phone if respond_to?(:phone)
      attrs[:custom_attributes] = instance_custom_attributes
      cognito_user = User.new(attrs)
      cognito_user.save!
      self.cognito_external_id = cognito_user.id
    end

    def instance_custom_attributes
      self._cognito_custom_attributes.map { |e| { name: e[:name], value: parse_custom_attribute_value(e[:value]) } }
    end

    def parse_custom_attribute_value value
      if value.is_a? Symbol
        self[value]
      else
        value
      end
    end

    def destroy_cognito_user
      cognito_user&.destroy!
    end

    class_methods do
      def find_by_cognito(external_id)
        find_by({  self._cognito_attribute_name => external_id })
      end

      def cognito_verify_email
        self._cognito_verify_email = true
      end

      def cognito_verify_phone
        self._cognito_verify_phone = true
      end

      def define_cognito_attribute(name, value)
        self._cognito_custom_attributes << { name: "custom:#{name}", value: value }
      end
    end
  end
end
