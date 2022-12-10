# frozen_string_literal: true

require 'jwt'
require 'open-uri'
require 'json'

module CognitoRails
  class JWT
    class << self
      # @param token [String] JWT token
      # @return [Array<Hash>,nil]
      def decode(token)
        aws_idp = with_cache { URI.open(jwks_url).read }
        jwt_config = JSON.parse(aws_idp, symbolize_names: true)

        ::JWT.decode(token, nil, true, { jwks: jwt_config, algorithms: ['RS256'] })
      rescue ::JWT::ExpiredSignature, ::JWT::VerificationError, ::JWT::DecodeError => e
        Config.logger&.error e.message
        nil
      end

      private

      def jwks_url
        "https://cognito-idp.#{Config.aws_region}.amazonaws.com/#{Config.aws_user_pool_id}/.well-known/jwks.json"
      end

      # @param block [Proc]
      # @yield [String] to be cached
      # @return [String] cached block
      def with_cache(&block)
        return yield unless Config.cache_adapter.respond_to?(:fetch)

        Config.cache_adapter.fetch('aws_idp', expires_in: 4.hours, &block)
      end
    end
  end
end
