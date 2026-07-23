require_relative '../rails_helper'

RSpec.describe 'Depending custom field format registration' do
  it 'registers all custom formats' do
    RedmineDependingCustomFields.register_formats
    expect(Redmine::FieldFormat.available_formats).to include(
      RedmineDependingCustomFields::FIELD_FORMAT_EXTENDED_USER,
      RedmineDependingCustomFields::FIELD_FORMAT_DEPENDING_LIST,
      RedmineDependingCustomFields::FIELD_FORMAT_DEPENDING_ENUMERATION
    )
  end
end
