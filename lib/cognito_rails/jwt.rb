# frozen_string_literal: true

require 'jwt'
require 'open-uri'
require 'json'

module CognitoRails
  class JWT
    class << self
      # @param token [String] JWT token
      # @param user_pool_id [String,nil] AWS Cognito User Pool ID
      # @param aws_region [String,nil] AWS region
      # @return [Array<Hash>,nil]
      def decode(token, user_pool_id: nil, aws_region: nil)
        url = jwks_url(user_pool_id: user_pool_id, aws_region: aws_region)
        aws_idp = with_cache(url) { URI.open(url).read }
        jwt_config = JSON.parse(aws_idp, symbolize_names: true)

        ::JWT.decode(token, nil, true, { jwks: jwt_config, algorithms: ['RS256'] })
      rescue ::JWT::ExpiredSignature, ::JWT::VerificationError, ::JWT::DecodeError => e
        Config.logger&.error e.message
        nil
      end

      private

      def jwks_url(user_pool_id: nil, aws_region: nil)
        user_pool_id ||= Config.aws_user_pool_id
        aws_region ||= Config.aws_region
        "https://cognito-idp.#{aws_region}.amazonaws.com/#{user_pool_id}/.well-known/jwks.json"
      end

      # @param cache_key [String]
      # @param block [Proc]
      # @yield [String] to be cached
      # @return [String] cached block
      def with_cache(cache_key, &block)
        return yield unless Config.cache_adapter.respond_to?(:fetch)

        Config.cache_adapter.fetch("aws_idp:#{cache_key}", expires_in: 4.hours, &block)
      end
    end
  end
end
