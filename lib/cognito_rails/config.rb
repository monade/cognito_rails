module CognitoRails
  class Config
    class << self
      def aws_access_key_id
        @aws_access_key_id || (raise RuntimeError, 'Missing config aws_access_key_id')
      end

      def aws_access_key_id=(value)
        @aws_access_key_id = value
      end

      def skip_model_hooks
        !!@skip_model_hooks
      end

      def skip_model_hooks=(value)
        @skip_model_hooks = value
      end

      def logger
        @logger
      end

      def logger=(value)
        @logger = value
      end

      def cache_adapter
        @cache_adapter
      end

      def cache_adapter=(value)
        @cache_adapter = value
      end

      def aws_region
        @aws_region || (raise RuntimeError, 'Missing config aws_region')
      end

      def aws_region=(value)
        @aws_region = value
      end

      def aws_secret_access_key
        @aws_secret_access_key || (raise RuntimeError, 'Missing config aws_secret_access_key')
      end

      def aws_secret_access_key=(value)
        @aws_secret_access_key = value
      end

      def aws_user_pool_id
        @aws_user_pool_id || (raise RuntimeError, 'Missing config aws_user_pool_id')
      end

      def aws_user_pool_id=(value)
        @aws_user_pool_id = value
      end

      def default_user_class
        @default_user_class || (raise RuntimeError, 'Missing config default_user_class')
      end

      def default_user_class=(value)
        @default_user_class = value
      end
    end
  end
end
