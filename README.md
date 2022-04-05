![Tests](https://github.com/monade/cognito_rails/actions/workflows/test.yml/badge.svg)

# cognito_rails

A gem to integrate AWS Cognito in your Rails app

## Installation

Add the gem to your Gemfile

```ruby
  gem 'cognito_rails', github: 'monade/cognito_rails'
```

Add an initializer for the configuration

```ruby
cognito_credentials = if Rails.env.production?
                        Rails.application.credentials&.dig(:cognito, :production)
                      else
                        Rails.application.credentials&.dig(:cognito, :staging)
                      end

CognitoRails::Config.aws_access_key_id = cognito_credentials&.dig(:access_key_id) || 'test'
CognitoRails::Config.aws_region = cognito_credentials&.dig(:region) || 'test'
CognitoRails::Config.aws_secret_access_key = cognito_credentials&.dig(:secret_access_key) || 'test'
CognitoRails::Config.aws_user_pool_id = cognito_credentials&.dig(:user_pool_id) || 'test'
CognitoRails::Config.default_user_class = 'User'
```

## Controller

Add the ControllerConcern to your ApplicationController:

```ruby
class ApplicationController < ActionController::Base
  include CognitoRails::ControllerConcern
end
```

This makes the logged user available to your controllers through the current_user attribute.

### Model

Add `as_cognito_user` to your user models along with the mixin methods you need:

```ruby
class User < ApplicationRecord
  validates :email, :phone, :role, presence: true
  validates :email, :phone, uniqueness: true

  as_cognito_user
  cognito_verify_email
  cognito_verify_phone
  define_cognito_attribute 'role', :role
  define_cognito_attribute 'test', 'some fixed value'

  as_queryable
  queryable filter: [], order: { created_at: :asc }
  has_many :projects, dependent: :restrict_with_error

  enum role: { user: 0, agency: 500, admin: 1000, superadmin: 9999 }
end
```

`:email` and `:phone` are automatically saved as Cognito attributes from the model.
`cognito_verify_email` and `cognito_verify_phone` add email and phone verification on user creation.
`define_cognito_attribute` assign a custom Cognito attribute to the user. **This won't work if you don't add the custom attribute through the Cognito console in advance**