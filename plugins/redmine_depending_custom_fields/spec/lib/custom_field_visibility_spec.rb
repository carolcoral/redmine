require_relative '../rails_helper'

RSpec.describe RedmineDependingCustomFields::CustomFieldVisibility do
  describe '.visible_to_user?' do
    let(:project) { instance_double(Project) }
    let(:custom_field) { instance_double(CustomField) }
    let(:user) { instance_double(User) }

    before do
      allow(user).to receive(:admin?).and_return(false)
      allow(custom_field).to receive(:visible?).and_return(false)
    end

    context 'when user is admin' do
      it 'returns true' do
        allow(user).to receive(:admin?).and_return(true)
        result = described_class.visible_to_user?(custom_field, project, user)
        expect(result).to be true
      end
    end

    context 'when user has a required role' do
      it 'returns true' do
        allow(custom_field).to receive(:role_ids).and_return([1, 2])
        role = instance_double(Role, id: 2)
        allow(user).to receive(:roles_for_project).with(project).and_return([role])

        result = described_class.visible_to_user?(custom_field, project, user)
        expect(result).to be true
      end
    end

    context 'when user lacks required roles' do
      it 'returns false' do
        allow(custom_field).to receive(:role_ids).and_return([1])
        role = instance_double(Role, id: 3)
        allow(user).to receive(:roles_for_project).with(project).and_return([role])

        result = described_class.visible_to_user?(custom_field, project, user)
        expect(result).to be false
      end
    end

    context 'when role information is missing' do
      it 'returns true if roles_for_project raises NoMethodError' do
        allow(custom_field).to receive(:role_ids).and_return([1])
        allow(user).to receive(:roles_for_project).and_raise(NoMethodError)

        result = described_class.visible_to_user?(custom_field, project, user)
        expect(result).to be true
      end

      it 'returns true if role_ids raises NoMethodError' do
        allow(custom_field).to receive(:role_ids).and_raise(NoMethodError)

        result = described_class.visible_to_user?(custom_field, project, user)
        expect(result).to be true
      end
    end
  end
end
