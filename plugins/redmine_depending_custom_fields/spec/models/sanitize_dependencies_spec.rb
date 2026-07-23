require_relative '../rails_helper'

RSpec.describe RedmineDependingCustomFields::Sanitizer do
  describe '.sanitize_dependencies' do
    subject { described_class.sanitize_dependencies(input) }

    context 'with nil input' do
      let(:input) { nil }

      it 'returns empty hash' do
        expect(subject).to eq({})
      end
    end

    context 'with non hash input' do
      let(:input) { 'foo' }

      it 'returns empty hash' do
        expect(subject).to eq({})
      end
    end

    context 'with blank keys and values' do
      let(:input) do
        {
          'a' => ['1', '', nil],
          '' => ['2'],
          nil => ['3'],
          :b => '2',
          'c' => [nil, ''],
          'd' => nil
        }
      end

      it 'returns sanitized hash with string keys and no blank values' do
        expect(subject).to eq({ 'a' => ['1'], 'b' => ['2'] })
      end
    end

    context 'with values as comma separated strings' do
      let(:input) { { 1 => '1' } }

      it 'wraps non array values into array of strings' do
        expect(subject).to eq({ '1' => ['1'] })
      end
    end
  end
end
