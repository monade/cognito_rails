# frozen_string_literal: true

require 'logger'

module CognitoRails
  class Config
    class << self
      # @raise [RuntimeError] if not set
      # @return [String] AWS access key id
      def aws_access_key_id
        # @type [String,nil]
        @aws_access_key_id || (raise 'Missing config aws_access_key_id')
      end

      # @!attribute aws_access_key_id [w]
      #   @return [String]
      # @!attribute aws_region [w]
      #   @return [String]
      # @!attribute aws_secret_access_key [w]
      #   @return [String]
      # @!attribute aws_user_pool_id [w]
      #   @return [String]
      # @!attribute default_user_class [w]
      #   @return [String,nil]
      attr_writer :aws_access_key_id, :skip_model_hooks, :aws_region,
                  :aws_secret_access_key, :aws_user_pool_id,
                  :default_user_class

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

      # @return [String] AWS secret access key
      # @raise [RuntimeError] if not set
      def aws_secret_access_key
        @aws_secret_access_key || (raise 'Missing config aws_secret_access_key')
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
    end
  end
end
