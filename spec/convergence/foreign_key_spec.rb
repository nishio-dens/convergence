require 'spec_helper'
require 'convergence/foreign_key'

describe Convergence::ForeignKey do
  describe '#initialize' do
    it 'wraps a single from_column/to_column into an array of strings' do
      fk = Convergence::ForeignKey.new('fk_name', :author_id, 'authors', :id, {})
      expect(fk.from_columns).to eq(['author_id'])
      expect(fk.to_columns).to eq(['id'])
    end

    it 'wraps multiple from_columns/to_columns into arrays of strings' do
      fk = Convergence::ForeignKey.new('fk_name', [:a_id, :b_id], 'targets', [:a, :b], {})
      expect(fk.from_columns).to eq(['a_id', 'b_id'])
      expect(fk.to_columns).to eq(['a', 'b'])
    end

    it 'stringifies the target table name' do
      fk = Convergence::ForeignKey.new('fk_name', :author_id, :authors, :id, {})
      expect(fk.to_table).to eq('authors')
    end

    it 'defaults the :name option to the key name' do
      fk = Convergence::ForeignKey.new('fk_name', :author_id, 'authors', :id, {})
      expect(fk.options[:name]).to eq('fk_name')
    end

    it 'preserves any additional options passed in' do
      fk = Convergence::ForeignKey.new('fk_name', :author_id, 'authors', :id, on_delete: :cascade)
      expect(fk.options[:on_delete]).to eq(:cascade)
    end
  end
end
