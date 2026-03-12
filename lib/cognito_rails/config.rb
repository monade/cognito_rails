# frozen_string_literal: true

require 'logger'

module CognitoRails
  class Config
    class << self
      # @return [String] AWS access key id
      def aws_client_credentials
        @aws_client_credentials || {}
      end

      # @!attribute aws_client_credentials [w]
      #   @return [Hash]
      # @!attribute aws_region [w]
      #   @return [String]
      # @!attribute aws_user_pool_id [w]
      #   @return [String]
      # @!attribute default_user_class [w]
      #   @return [String,nil]
      attr_writer :aws_client_credentials, :skip_model_hooks, :aws_region,
                  :aws_user_pool_id, :default_user_class, :password_generator

      # @return [Boolean] skip model hooks
      def skip_model_hooks
        !!@skip_model_hooks
      end

      # @!attribute logger [rw]
      #   @return [Logger]
      # @!attribute cache_adapter [rw]
      #   @return [#fetch,nil]
      attr_accessor :logger, :cache_adapter

      # @return [String] AWS region
      # @raise [RuntimeError] if not set
      def aws_region
        @aws_region || (raise 'Missing config aws_region')
      end

      # @return [String] AWS user pool id
      # @raise [RuntimeError] if not set
      def aws_user_pool_id
        @aws_user_pool_id || (raise 'Missing config aws_user_pool_id')
      end

      # @return [String] default user class
      # @raise [RuntimeError] if not set
      def default_user_class
        @default_user_class || (raise 'Missing config default_user_class')
      end

      # @param user_class [String,Symbol,Class,nil]
      # @param options [Hash]
      # @return [void]
      def register_user_scope(user_class, options = {})
        user_class = CognitoRails::Utils.resolve_model_class(user_class)
        return if user_class.nil?

        options = options.with_indifferent_access

        user_scopes[user_class.name] = {
          user_pool_id: options[:user_pool_id],
          aws_region: options[:aws_region],
          access_key_id: options[:access_key_id],
          secret_access_key: options[:secret_access_key]
        }.compact.with_indifferent_access
      end

      # @param user_class [String,Symbol,Class,nil]
      # @return [Hash]
      def user_scope_for(user_class)
        user_class = CognitoRails::Utils.resolve_model_class(user_class)
        return {} if user_class.nil?

        (user_scopes[user_class.name] || {}).dup.with_indifferent_access
      end

      def password_generator
        @password_generator || CognitoRails::PasswordGenerator.method(:generate)
      end

      private

      # @return [Hash{String => Hash}]
      def user_scopes
        @user_scopes ||= {}
      end
    end
  end
end
