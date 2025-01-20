# Changelog
All notable changes to this project made by Monade Team are documented in this file. For info refer to team@monade.io

## [1.4.0] - 2025-01-20
### Added
- Support for Rails 8
- Support for ruby 3.4

### Removed
- Drop support for Rails 5
- Drop support for Ruby 2.7

## [1.3.0] - 2023-06-09
### Added
- `cognito_password_policy` model attribute to specify cognito password policy on user creation

## [1.2.0] - 2023-05-23
### Added
- `sync_from_cognito!` now accepts a block to configure extra fields before save

## [1.1.0] - 2023-04-27
### Added
- A password generator that follows [Cognito policies](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-policies.html)

### Fixed
- Allow passing a custom password generator
- Override default password generated when explicitly passing one to the model

## [1.0.0] - 2023-03-30
### Added
- `sync_from_cognito!` to create users in the local database from cognito
- `sync_to_cognito!` to create cognito users based from the local database

### Changed
- [BREAKING] Switched from explicit `aws_access_key`/`aws_secret_access_key` to a more flexible `aws_client_credentials`

### Removed
- `Rails` module references

## [0.1.0] - 2022-05-28
### Added
- First release
