require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

class User < ActiveRecord::Base
  validates :email, presence: true
  validates :email, uniqueness: true

  as_cognito_user
end

module Schema
  def self.create
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define do
      create_table :users, force: true do |t|
        t.string "email", null: false
        t.string "external_id", null: false
        t.timestamps null: false
      end
    end

  end
end