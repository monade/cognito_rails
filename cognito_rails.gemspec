$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'cognito_rails/version'

Gem::Specification.new do |s|
  s.name = 'cognito_rails'
  s.version = CognitoRails::VERSION
  s.summary = 'Add Cognito authentication to your Rails API'
  s.description = 'Add Cognito authentication to your Rails API'
  s.authors = ['Mònade']
  s.email = 'team@monade.io'
  s.files = Dir['lib/**/*']
  s.test_files = Dir['spec/**/*']
  s.required_ruby_version = '>= 2.7.0'
  s.homepage    = 'https://rubygems.org/gems/monade-cognito'
  s.license     = 'MIT'
  s.add_dependency 'activesupport', ['>= 5', '< 8']
  s.add_dependency 'jwt'
  s.add_dependency 'aws-sdk-cognitoidentityprovider'
  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'rubocop'
end
