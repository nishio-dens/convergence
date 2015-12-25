require 'spec_helper'

describe Convergence::Table do
  let(:table_name) { 'dummy_table' }
  let(:table) { Convergence::Table.new(table_name) }
  let(:dummy_column) { 'dummy_column' }

  describe 'column' do
    it 'should be able to set type' do
      table.int(dummy_column)
      expect(table.columns[dummy_column].type).to eq(:int)
    end

    it 'should be able to set column_name' do
      table.int(dummy_column)
      expect(table.columns[dummy_column].column_name).to eq(dummy_column)
    end

    it 'should be able to set options' do
      table.int(dummy_column, limit: 100)
      expect(table.columns[dummy_column].options[:limit]).to eq(100)
    end

    it 'should convert the default value to float for floating-point columns' do
      table.decimal(dummy_column, default: 1)
      expect(table.columns[dummy_column].options[:default]).to eq(1.0)
    end
  end

  describe '#index' do
    context 'when option name is nil' do
      it 'should generate index name' do
        table.index(dummy_column)
        index = table.indexes.first[1]
        expect(index.index_name).not_to be_nil
        expect(index.index_name).to eq "index_#{table_name}_on_#{dummy_column}"
      end
    end

    it 'should be able to set index name' do
      table.index(dummy_column, name: 'index_test')
      index = table.indexes.first[1]
      expect(index.index_name).to eq('index_test')
    end

    it 'should be able to set index_column' do
      table.index(dummy_column)
      expect(table.indexes.first[1].index_columns).to eq([dummy_column])
    end

    it 'should be able to handle multiple index columns' do
      table.index(%w(a b))
      expect(table.indexes.first[1].index_columns).to eq(%w(a b))
    end

    it 'should be able to set options' do
      table.index(dummy_column, using: 'btree')
      expect(table.indexes.first[1].options[:using]).to eq('btree')
    end
  end

  describe '#foreign_key' do
    def fk
      table.foreign_keys.first[1]
    end

    context 'when reference is nil' do
      it 'should be raise error' do
        expect { table.foreign_key(dummy_column, reference: nil, reference_column: 'dummy') }.to raise_error
      end
    end

    context 'when reference_column is nil' do
      it 'should be raise error' do
        expect { table.foreign_key(dummy_column, reference: 'dummy', reference_column: nil) }.to raise_error
      end
    end

    context 'when key name is nil' do
      it 'should be able to generate foreign key name' do
        table.foreign_key(dummy_column, reference: 'a', reference_column: 'b')
        expect(fk.key_name).to eq("#{table_name}_#{dummy_column}_fk")
      end
    end

    it 'should be able to set key name' do
      table.foreign_key(dummy_column, reference: 'a', reference_column: 'b', name: 'key')
      expect(fk.key_name).to eq('key')
    end

    it 'should be able to set multiple from columns' do
      table.foreign_key(%w(column1 column2), reference: 'a', reference_column: 'b')
      expect(fk.from_columns).to eq(%w(column1 column2))
    end

    it 'should be able to set to_table' do
      table.foreign_key(dummy_column, reference: 'ref_table', reference_column: 'ref_column')
      expect(fk.to_table).to eq('ref_table')
    end

    it 'should be able to set to_columns' do
      table.foreign_key(dummy_column, reference: 'ref_table', reference_column: 'ref_column')
      expect(fk.to_columns).to eq(['ref_column'])
    end

    it 'should be able to set options' do
      table.foreign_key(dummy_column, reference: 'ref_table', reference_column: 'ref_column', extra: true)
      expect(fk.options[:extra]).not_to be_nil
    end
  end
end
