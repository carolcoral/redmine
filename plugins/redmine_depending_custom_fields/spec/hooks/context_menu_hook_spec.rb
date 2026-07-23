require_relative '../rails_helper'

RSpec.describe RedmineDependingCustomFields::Hooks::ContextMenuHook do
  let(:hook) { described_class.send(:new) }
  let(:view_context) { double('view', extend: nil) }
  let(:controller) { double('controller', view_context: view_context, current_user: user) }
  let(:user) { instance_double(User) }
  let(:project1) { instance_double(Project) }
  let(:project2) { instance_double(Project) }
  let(:issue1) { instance_double(Issue, project: project1) }
  let(:issue2) { instance_double(Issue, project: project2) }
  let(:issues) { [issue1, issue2] }

  before do
    allow(RedmineDependingCustomFields::ParentMenuBuilder).to receive(:build).and_return([])
    allow(Rails.cache).to receive(:fetch).and_return({})
  end

  context 'when user lacks permission on one issue' do
    before do
      allow(user).to receive(:allowed_to?).with(:edit_issues, project1).and_return(false)
    end

    it 'skips rendering the wizard' do
      expect(view_context).not_to receive(:render)
      hook.view_issues_context_menu_end(issues: issues, controller: controller)
    end
  end

  context 'when user has permission on all issues' do
    before do
      allow(user).to receive(:allowed_to?).with(:edit_issues, project1).and_return(true)
      allow(user).to receive(:allowed_to?).with(:edit_issues, project2).and_return(true)
    end

    it 'renders the wizard partial' do
      expect(view_context).to receive(:render)
      hook.view_issues_context_menu_end(issues: issues, controller: controller)
    end
  end
end
