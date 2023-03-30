# Changelog
All notable changes to this project made by Monade Team are documented in this file. For info refer to team@monade.io

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
