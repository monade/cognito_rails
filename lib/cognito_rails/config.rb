class CognitoRails::Config
  class << self
    def aws_access_key_id
      @aws_access_key_id || (raise RuntimeError, 'Missing config aws_access_key_id')
    end

    def aws_access_key_id=(value)
      @aws_access_key_id = value
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
  end
end