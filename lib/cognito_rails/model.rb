# frozen_string_literal: true

require 'active_record'

module CognitoRails
  # ActiveRecord model extension
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :_cognito_verify_email
      class_attribute :_cognito_verify_phone
      class_attribute :_cognito_custom_attributes
      class_attribute :_cognito_attribute_name
      self._cognito_custom_attributes = []

      before_create do
        init_cognito_user unless CognitoRails::Config.skip_model_hooks
      end

      after_destroy do
        destroy_cognito_user unless CognitoRails::Config.skip_model_hooks
      end
    end

    # rubocop:disable Metrics/BlockLength
    class_methods do
      # @return [Array<ActiveRecord::Base>] all users
      # @raise [CognitoRails::Error] if failed to fetch users
      # @raise [ActiveRecord::RecordInvalid] if failed to save user
      def sync_from_cognito!
        response = User.all
        response.users.map do |user_data|
          sync_user!(user_data)
        end
      end

      # @return [Array<ActiveRecord::Base>] all users
      # @raise [CognitoRails::Error] if failed to fetch users
      # @raise [ActiveRecord::RecordInvalid] if failed to save user
      def sync_to_cognito!
        find_each.map do |user|
          user.init_cognito_user
          user.save!
        end
      end

      private

      def sync_user!(user_data)
        external_id = user_data.username
        return if external_id.blank?

        user = find_or_initialize_by(_cognito_attribute_name => external_id)
        user.email = User.extract_cognito_attribute(user_data.attributes, :email)
        user.phone = User.extract_cognito_attribute(user_data.attributes, :phone_number) if user.respond_to?(:phone)
        _cognito_resolve_custom_attribute(user, user_data)

        user.save!
        user
      end

      def _cognito_resolve_custom_attribute(user, user_data)
        _cognito_custom_attributes.each do |attribute|
          next if attribute[:value].is_a?(String)

          value = User.extract_cognito_attribute(user_data.attributes, attribute[:name])
          next unless value

          user[attribute[:name].gsub('custom:', '')] = value
        end
      end
    end

    # @return [String]
    def cognito_external_id
      self[self.class._cognito_attribute_name]
    end

    # @param value [String]
    # @return [String]
    def cognito_external_id=(value)
      self[self.class._cognito_attribute_name] = value
    end

    def cognito_user
      @cognito_user ||= User.find(cognito_external_id, user_class: self.class)
    end

    protected

    def init_cognito_user
      return if cognito_external_id.present?

      cognito_user = User.new(init_attributes)
      cognito_user.save!
      self.cognito_external_id = cognito_user.id
    end

    def init_attributes
      attrs = { email: email, user_class: self.class }
      attrs[:phone] = phone if respond_to?(:phone)
      attrs[:password] = password if respond_to?(:password)
      attrs[:custom_attributes] = instance_custom_attributes
      attrs
    end

    # @return [Array<Hash>]
    def instance_custom_attributes
      _cognito_custom_attributes.map { |e| { name: e[:name], value: parse_custom_attribute_value(e[:value]) } }
    end

    def parse_custom_attribute_value(value)
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
      # @param name [String] attribute name
      # @return [ActiveRecord::Base] model class
      def find_by_cognito(external_id)
        find_by({ _cognito_attribute_name => external_id })
      end

      def cognito_verify_email
        self._cognito_verify_email = true
      end

      def cognito_verify_phone
        self._cognito_verify_phone = true
      end

      # @param name [String] attribute name
      # @param value [String] attribute name
      def define_cognito_attribute(name, value)
        _cognito_custom_attributes << { name: "custom:#{name}", value: value }
      end
    end
  end
end
