require 'spec_helper'
require 'convergence/index'

describe Convergence::Index do
  describe '#initialize' do
    it 'defaults the :name option to the index name' do
      index = Convergence::Index.new('idx_name', 'name', {})
      expect(index.options[:name]).to eq('idx_name')
    end

    it 'wraps a single column into an array of strings' do
      index = Convergence::Index.new('idx_name', :name, {})
      expect(index.index_columns).to eq(['name'])
    end

    it 'wraps multiple columns into an array of strings' do
      index = Convergence::Index.new('idx_name', [:first_name, :last_name], {})
      expect(index.index_columns).to eq(['first_name', 'last_name'])
    end

    context 'when length is a single Integer' do
      it 'applies it to every column' do
        index = Convergence::Index.new('idx_name', [:first_name, :last_name], length: 10)
        expect(index.options[:length]).to eq('first_name' => 10, 'last_name' => 10)
      end
    end

    context 'when length is a Hash keyed by symbol' do
      it 'normalizes the keys to strings' do
        index = Convergence::Index.new('idx_name', [:first_name, :last_name], length: { first_name: 10, last_name: 20 })
        expect(index.options[:length]).to eq('first_name' => 10, 'last_name' => 20)
      end
    end
  end

  describe '#quoted_columns' do
    it 'quotes each column name with backticks' do
      index = Convergence::Index.new('idx_name', [:first_name, :last_name], {})
      expect(index.quoted_columns).to eq(['`first_name`', '`last_name`'])
    end

    it 'appends the prefix length in parentheses when configured' do
      index = Convergence::Index.new('idx_name', [:first_name, :last_name], length: { first_name: 10 })
      expect(index.quoted_columns).to eq(['`first_name`(10)', '`last_name`'])
    end

    it 'escapes a backtick embedded in a column name' do
      index = Convergence::Index.new('idx_name', 'weird`name', {})
      expect(index.quoted_columns).to eq(['`weird``name`'])
    end
  end
end
