module CognitoRails
  class User
    include ActiveModel::Validations

    attr_accessor :id, :email, :password, :phone, :user_class

    validates :email, presence: true

    def initialize(attributes = {})
      attributes = attributes.with_indifferent_access
      self.email = attributes[:email]
      self.password = SecureRandom.urlsafe_base64 || attributes[:password]
      self.phone = attributes[:phone]
      self.user_class = attributes[:user_class] || Config.default_user_class.constantize
    end

    def self.find(id, user_class = nil)
      result = cognito_client.admin_get_user(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id, # required
          username: id # required
        }
      )
      user = new(user_class:)
      user.id = result.username
      user.email = result.user_attributes.find { |attribute| attribute[:name] == 'email' }[:value]
      user.phone = result.user_attributes.find { |attribute| attribute[:name] == 'phone_number' }&.dig(:value)
      user
    end

    def self.create!(attributes = {})
      user = new(attributes)
      user.save!
      user
    end

    def self.create
      user = new(attributes)
      user.save
      user
    end

    def new_record?
      !persisted?
    end

    def persisted?
      id.present?
    end

    def save!
      save || (raise ActiveRecord::RecordInvalid, self)
    end
# split into save_create and save_update (line 54)
    def save
      return false unless validate
      if persisted?
        save_update
      else
        save_create
      end

      true
    end

    def destroy
      return false if new_record?

      cognito_client.admin_delete_user(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id,
          username: id
        }
      )
      self.id = nil

      true
    end

    def destroy!
      destroy || (raise ActiveRecord::RecordInvalid, self)
    end

    private

    def cognito_client
      self.class.cognito_client
    end

    def verify_email?
      self.user_class._cognito_verify_email
    end

    def verify_phone?
      self.user_class._cognito_verify_phone
    end

    def custom_attributes
      self.user_class._cognito_attributes
    end

    def self.cognito_client
      raise 'Can\'t create user in test mode' if Rails.env.test?

      @cognito_client ||= Aws::CognitoIdentityProvider::Client.new(
        access_key_id: CognitoRails::Config.aws_access_key_id,
        secret_access_key: CognitoRails::Config.aws_secret_access_key,
        region: CognitoRails::Config.aws_region
      )
    end

    def general_user_attributes

      email_attributes = email.nil? ? [] : [
        {
          name: 'email',
          value: email
        }
      ]
      phone_attributes = phone.nil? ? [] : [
        {
          name: 'phone_number',
          value: phone
        }
      ]

      [
        *email_attributes,
        *phone_attributes,
        *custom_attributes
      ]
    end

    def verify_user_attributes
      verify_email_attributes = !verify_email? ? [] : [
        {
          name: 'email_verified',
          value: 'True'
        }
      ]
      verify_phone_attributes = !verify_phone? ? [] : [
        {
          name: 'phone_number_verified',
          value: 'True'
        }
      ]
    end

    def save_create
      resp = cognito_client.admin_create_user(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id, # required
          username: email, # required
          temporary_password: password, # required
          user_attributes: [
            *general_user_attributes,
            *verify_user_attributes
          ],
        }
      )
      self.id = resp.user.attributes.find { |a| a[:name] == 'sub' }[:value]
    end

    def save_update
      resp = cognito_client.admin_update_user_attributes(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id, # required
          username: id, # required
          user_attributes: [
            *general_user_attributes
          ]
        }
      )
    end
  end
end