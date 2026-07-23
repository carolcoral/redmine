require_relative '../rails_helper'

RSpec.describe RedmineDependingCustomFields::Patches::QueryCustomFieldColumnPatch do
  class DummyQueryCustomFieldColumn
    attr_reader :sortable
    def initialize(_custom_field, options = {})
      @sortable = options[:sortable]
    end
  end

  before do
    DummyQueryCustomFieldColumn.prepend described_class
  end

  it 'sets sortable to the custom field order statement when available' do
    custom_field = double('CustomField', order_statement: 'cf_table.field ASC')
    column = DummyQueryCustomFieldColumn.new(custom_field)
    expect(column.sortable).to eq('cf_table.field ASC')
  end
end
