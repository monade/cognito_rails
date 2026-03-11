# frozen_string_literal: true

module CognitoRails
  module Utils
    class << self
      # @param model_class [String,Symbol,Class,nil]
      # @return [Class,nil]
      def resolve_model_class(model_class)
        case model_class
        when nil
          nil
        when String, Symbol
          model_class.to_s.constantize
        else
          model_class
        end
      end
    end
  end
end
