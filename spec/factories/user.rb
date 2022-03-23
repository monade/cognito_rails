FactoryBot.define do
  factory :user do
    sequence(:email) { |i| "email#{i}@cognito.com" }
    sequence(:external_id) { |k| "extenralid-#{k}" }
  end
end