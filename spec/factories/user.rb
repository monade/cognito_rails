FactoryBot.define do
  factory :user do
    sequence(:email) { |i| "email#{i}@cognito.com" }
    sequence(:name) { |i| "TestName" }
    sequence(:external_id) { |k| "extenralid-#{k}" }
  end
end