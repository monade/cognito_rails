require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

class User < ActiveRecord::Base
  validates :email, presence: true
  validates :email, uniqueness: true

  as_cognito_user
  cognito_verify_email
  define_cognito_attribute 'role', 'user'
  define_cognito_attribute 'name', :name

  attr_accessor :password
end

class EnrichedUser < ActiveRecord::Base
  validates :email, presence: true
  validates :email, uniqueness: true
  validates :first_name, :last_name, presence: true

  as_cognito_user
  cognito_verify_email
  define_cognito_attribute 'role', 'user'

  attr_accessor :password
end


class Admin < ActiveRecord::Base
  validates :email, presence: true
  validates :email, uniqueness: true
  validates :phone, presence: true
  validates :phone, uniqueness: true

  as_cognito_user attribute_name: 'cognito_id'
  cognito_verify_email
  cognito_verify_phone
  define_cognito_attribute 'role', 'admin'
end

module Schema
  def self.create
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define do
      create_table :users, force: true do |t|
        t.string "email", null: false
        t.string "name"
        t.string "external_id", null: false
        t.timestamps null: false
      end

      create_table :enriched_users, force: true do |t|
        t.string "email", null: false
        t.string "first_name", null: false
        t.string "last_name", null: false
        t.string "external_id", null: false
        t.timestamps null: false
      end

      create_table :admins, force: true do |t|
        t.string "email", null: false
        t.string "phone", null: false
        t.string "cognito_id", null: false
        t.timestamps null: false
      end
    end

  end
end
