require 'rails_helper'

RSpec.describe 'DependingCustomFields API', type: :request do
  let(:cf) { build_custom_field(id: 1) }

  before do
    allow(User).to receive(:current).and_return(instance_double(User, admin?: true))
  end

  describe 'authentication' do
    it 'requires login' do
      allow(User).to receive(:current).and_return(User.anonymous)
      get '/depending_custom_fields.json'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies non admin users' do
      allow(User).to receive(:current).and_return(instance_double(User, admin?: false))
      get '/depending_custom_fields.json'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /depending_custom_fields' do
    before do
      allow(CustomField).to receive(:where).and_return([cf])
      allow_any_instance_of(DependingCustomFieldsApiController).to receive(:format_custom_field).and_return(id: cf.id)
    end

    it 'lists custom fields' do
      get '/depending_custom_fields.json'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([{ 'id' => 1 }])
    end
  end

  describe 'GET /depending_custom_fields/:id' do
    context 'when field exists' do
      before do
        allow(CustomField).to receive(:find).with('1').and_return(cf)
        allow_any_instance_of(DependingCustomFieldsApiController).to receive(:format_custom_field).and_return(id: cf.id)
      end

      it 'shows the field' do
        get '/depending_custom_fields/1.json'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq('id' => 1)
      end
    end

    context 'when field is missing' do
      before do
        allow(CustomField).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'returns 404' do
        get '/depending_custom_fields/99.json'
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /depending_custom_fields' do
    let(:params) { { custom_field: { name: 'CF', type: 'IssueCustomField', field_format: 'list' } } }
    let(:new_cf) { build_custom_field(id: 2) }

    before do
      stub_const('IssueCustomField', Class.new)
      allow(IssueCustomField).to receive(:new).and_return(new_cf)
      allow_any_instance_of(DependingCustomFieldsApiController).to receive(:assign_enumerations)
      allow_any_instance_of(DependingCustomFieldsApiController).to receive(:format_custom_field).and_return(id: new_cf.id)
    end

    context 'with valid params' do
      before { allow(new_cf).to receive(:save).and_return(true) }

      it 'creates a field' do
        post '/depending_custom_fields.json', params: params
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      before do
        allow(new_cf).to receive(:save).and_return(false)
        allow(new_cf).to receive(:errors).and_return(double(full_messages: ['invalid']))
      end

      it 'returns errors' do
        post '/depending_custom_fields.json', params: params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq('errors' => ['invalid'])
      end
    end
  end

  describe 'PUT /depending_custom_fields/:id' do
    let(:params) { { custom_field: { name: 'Updated' } } }

    before do
      allow(CustomField).to receive(:find).with('1').and_return(cf)
      allow(cf).to receive(:assign_attributes)
      allow_any_instance_of(DependingCustomFieldsApiController).to receive(:assign_enumerations)
      allow_any_instance_of(DependingCustomFieldsApiController).to receive(:format_custom_field).and_return(id: cf.id)
    end

    context 'when update succeeds' do
      before { allow(cf).to receive(:save).and_return(true) }

      it 'updates the field' do
        put '/depending_custom_fields/1.json', params: params
        expect(cf).to have_received(:assign_attributes).with(params[:custom_field])
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when update fails' do
      before do
        allow(cf).to receive(:save).and_return(false)
        allow(cf).to receive(:errors).and_return(double(full_messages: ['bad']))
      end

      it 'returns errors' do
        put '/depending_custom_fields/1.json', params: params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq('errors' => ['bad'])
      end
    end
  end

  describe 'DELETE /depending_custom_fields/:id' do
    before do
      allow(CustomField).to receive(:find).with('1').and_return(cf)
      allow(cf).to receive(:destroy)
    end

    it 'destroys the field' do
      delete '/depending_custom_fields/1.json'
      expect(cf).to have_received(:destroy)
      expect(response).to have_http_status(:no_content)
    end
  end
end
