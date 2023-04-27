# frozen_string_literal: true

module CognitoRails
  class PasswordGenerator
    NUMERIC = (0..9).to_a.freeze
    LOWER_CASE = ('a'..'z').to_a.freeze
    UPPER_CASE = ('A'..'Z').to_a.freeze
    SPECIAL = [
      '^', '$', '*', '.', '[', ']', '{', '}',
      '(', ')', '?', '"', '!', '@', '#', '%',
      '&', '/', '\\', ',', '>', '<', "'", ':',
      ';', '|', '_', '~', '`', '=', '+', '-'
    ].freeze

    # Generates a random password given a length range
    #
    # @param range [Range]
    # @return [String]
    def self.generate(range = 8..16)
      password_length = rand(range)
      numeric_count = rand(1..(password_length-3))

      lower_case_count = rand(1..(password_length-(numeric_count+2)))
      upper_case_count = rand(1..(password_length-(numeric_count + lower_case_count + 1)))
      special_count = password_length-(numeric_count + lower_case_count + upper_case_count)

      numeric_characters = numeric_count.times.map { NUMERIC.sample }
      lower_case_characters = lower_case_count.times.map { LOWER_CASE.sample }
      upper_case_characters = upper_case_count.times.map { UPPER_CASE.sample }
      special_characters = special_count.times.map { SPECIAL.sample }

      (numeric_characters + lower_case_characters + upper_case_characters + special_characters).shuffle.join
    end
  end
end
