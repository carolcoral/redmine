require 'rails_helper'

RSpec.describe 'DependingCustomFields API cache', type: :request do
  before do
    @events = []
    @subscriber = ActiveSupport::Notifications.subscribe('cache_delete.active_support') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      @events << event.payload[:key]
    end
  end

  after do
    ActiveSupport::Notifications.unsubscribe(@subscriber)
  end

  it 'clears cache on create' do
    post '/depending_custom_fields',
         params: { custom_field: { name: 'CF', type: 'IssueCustomField', field_format: 'depending_list', possible_values: ['A', 'B'] } },
         session: { user_id: 1 }
    expect(response).to have_http_status(:created)
    expect(@events).to include('depending_custom_fields/mapping')
    expect(@events).to include('dcf/*')
  end

  it 'clears cache on update' do
    cf = IssueCustomField.create!(name: 'CF', field_format: 'depending_list', possible_values: ['A'])
    put "/depending_custom_fields/#{cf.id}",
        params: { custom_field: { possible_values: ['A', 'B'] } },
        session: { user_id: 1 }
    expect(response).to have_http_status(:ok)
    expect(@events).to include('depending_custom_fields/mapping')
    expect(@events).to include('dcf/*')
  end
end

