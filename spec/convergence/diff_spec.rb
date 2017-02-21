require 'spec_helper'

describe Convergence::DSL do
  describe '#diff' do
    let(:simple_table) do
      Convergence::Table.new('simple_table').tap do |t|
        t.int('id', primary_key: true)
      end
    end
    let(:simple_table2) do
      Convergence::Table.new('simple_table2').tap do |t|
        t.int('id', primary_key: true)
      end
    end

    context 'when from database and to database are same' do
      let(:from_db) do
        { 'simple_table' => simple_table }
      end
      let(:to_db) do
        from_db
      end

      subject { Convergence::Diff.new.diff(from_db, to_db) }

      it 'should return empty' do
        expect(subject[:add_table]).to be_empty
        expect(subject[:remove_table]).to be_empty
        expect(subject[:change_table]).to be_empty
      end
    end

    context 'when new tables are added' do
      let(:from_db) do
        { 'simple_table' => simple_table }
      end
      let(:to_db) do
        { 'simple_table' => simple_table, 'simple_table2' => simple_table2 }
      end

      subject { Convergence::Diff.new.diff(from_db, to_db) }

      it 'should be able to detect add table' do
        expect(subject[:add_table]).not_to be_empty
        expect(subject[:add_table]['simple_table2']).not_to be_nil
      end
    end

    context 'when tables are removed' do
      let(:from_db) do
        { 'simple_table' => simple_table, 'simple_table2' => simple_table2 }
      end
      let(:to_db) do
        { 'simple_table' => simple_table }
      end

      subject { Convergence::Diff.new.diff(from_db, to_db) }

      it 'should be able to detect remove table' do
        expect(subject[:remove_table]).not_to be_empty
        expect(subject[:remove_table]['simple_table2']).not_to be_nil
      end
    end

    context 'table column are changed' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end

      context 'new column are added' do
        let(:table_to) do
          Convergence::Table.new('table1').tap do |t|
            t.int('id', primary_key: true)
            t.varchar('name', limit: 200, null: false)
            t.varchar('data', limit: 300, null: false)
          end
        end

        it do
          results = Convergence::Diff.new.diff({ 'table1' => table_from }, { 'table1' => table_to })
          expect(results[:change_table]).not_to be_empty
        end
      end

      context 'column are deleted' do
        let(:table_to) do
          Convergence::Table.new('table1').tap do |t|
            t.int('id', primary_key: true)
          end
        end

        it do
          results = Convergence::Diff.new.diff({ 'table1' => table_from }, { 'table1' => table_to })
          expect(results[:change_table]).not_to be_empty
        end
      end

      context 'column definition are changed' do
        let(:table_to) do
          Convergence::Table.new('table1').tap do |t|
            t.int('id')
          end
        end

        it do
          results = Convergence::Diff.new.diff({ 'table1' => table_from }, { 'table1' => table_to })
          expect(results[:change_table]).not_to be_empty
        end
      end

      context 'all columns are replaced' do
        let(:table_to) do
          Convergence::Table.new('table1').tap do |t|
            t.int('id_rename', primary_key: true)
            t.varchar('name_rename', limit: 200, null: false)
            t.varchar('data_rename', limit: 300, null: false)
          end
        end

        it do
          results = Convergence::Diff.new.diff({ 'table1' => table_from }, { 'table1' => table_to })
          expect(results[:add_table]).not_to be_empty
          expect(results[:remove_table]).not_to be_empty
          expect(results[:change_table]).to be_empty
          included_after_option = results[:add_table].each_value.map { |t| t.columns.each_value.map { |c| c.options.key?(:after) } }.flatten.any?
          expect(included_after_option).to eq false
        end
      end
    end
  end

  describe '#diff_table' do
    let(:table_from) do
      Convergence::Table.new('table1').tap do |t|
        t.int('id', primary_key: true)
        t.varchar('name', limit: 200, null: false)

        t.index('name')
        t.foreign_key('id', reference: 'ref_tables', reference_column: 'ref_id')
      end
    end

    context 'change column options' do
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 300, null: true, unsigned: true)

          t.index('name')
        end
      end

      it do
        results = Convergence::Diff.new.diff_table(table_from, table_to)
        expect(results[:change_column]['name']).not_to be_nil
        expect(results[:change_column]['name'][:limit]).to eq('300')
        expect(results[:change_column]['name'][:null]).to eq('true')
        expect(results[:change_column]['name'][:unsigned]).to eq('true')
      end
    end

    context 'change column order' do
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.varchar('name', limit: 300, null: true)
          t.int('id', primary_key: true)

          t.index('name')
        end
      end

      it do
        results = Convergence::Diff.new.diff_table(table_from, table_to)
        expect(results[:change_column]['name']).not_to be_nil
        expect(results[:change_column]['id']).not_to be_nil
        expect(results[:change_column]['id'][:after]).to eq('name')
      end
    end

    context 'remove index' do
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 300, null: true)
        end
      end

      it do
        results = Convergence::Diff.new.diff_table(table_from, table_to)
        expect(results[:remove_index].values.first.index_columns).to eq(['name'])
      end
    end

    context 'add index' do
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 300, null: true)

          t.index('id')
          t.index('name')
        end
      end

      it do
        results = Convergence::Diff.new.diff_table(table_from, table_to)
        expect(results[:add_index].values.first.index_columns).to eq(['id'])
      end
    end

    context 'remove foreign key' do
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 300, null: true)

          t.index('name')
        end
      end

      it do
        results = Convergence::Diff.new.diff_table(table_from, table_to)
        expect(results[:remove_foreign_key].values.first.from_columns).to eq(['id'])
      end
    end

    context 'add foreign key' do
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 300, null: true)

          t.index('name')
          t.foreign_key('id', reference: 'ref_tables', reference_column: 'ref_id')
          t.foreign_key('id2', reference: 'ref_tables2', reference_column: 'ref_id2')
        end
      end

      it do
        results = Convergence::Diff.new.diff_table(table_from, table_to)
        expect(results[:add_foreign_key].values.first.from_columns).to eq(['id2'])
      end
    end

    context 'change table options' do
      let(:table_to) do
        Convergence::Table.new('table1', engine: 'MyISAM').tap do |t|
          t.varchar('name', limit: 300, null: true)
          t.int('id', primary_key: true)
        end
      end

      it do
        results = Convergence::Diff.new.diff_table(table_from, table_to)
        expect(results[:change_table_option][:engine]).to eq('MyISAM')
      end
    end
  end
end
