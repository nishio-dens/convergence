require 'spec_helper'
require 'convergence/diff'
require 'convergence/table'

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

    context 'when a table is renamed' do
      let(:renamed_table) do
        Convergence::Table.new('simple_table_renamed', renamed_from: 'simple_table').tap do |t|
          t.int('id', primary_key: true)
        end
      end
      let(:from_db) do
        { 'simple_table' => simple_table }
      end
      let(:to_db) do
        { 'simple_table_renamed' => renamed_table }
      end

      subject { Convergence::Diff.new.diff(from_db, to_db) }

      it 'should detect it as a rename, not add/remove' do
        expect(subject[:rename_table]).to eq('simple_table' => 'simple_table_renamed')
        expect(subject[:add_table]).to be_empty
        expect(subject[:remove_table]).to be_empty
        expect(subject[:change_table]).to be_empty
      end
    end

    context 'when renamed_from references a table that does not exist' do
      let(:renamed_table) do
        Convergence::Table.new('simple_table2', renamed_from: 'nonexistent_table').tap do |t|
          t.int('id', primary_key: true)
        end
      end
      let(:from_db) do
        { 'simple_table' => simple_table }
      end
      let(:to_db) do
        { 'simple_table' => simple_table, 'simple_table2' => renamed_table }
      end

      subject { Convergence::Diff.new.diff(from_db, to_db) }

      it 'should fall back to a normal add' do
        expect(subject[:rename_table]).to be_empty
        expect(subject[:add_table]['simple_table2']).not_to be_nil
      end
    end

    context 'when the renamed_from target already exists (idempotent re-apply)' do
      let(:renamed_table) do
        Convergence::Table.new('simple_table2', renamed_from: 'simple_table').tap do |t|
          t.int('id', primary_key: true)
        end
      end
      let(:from_db) do
        { 'simple_table' => simple_table, 'simple_table2' => simple_table2 }
      end
      let(:to_db) do
        { 'simple_table' => simple_table, 'simple_table2' => renamed_table }
      end

      subject { Convergence::Diff.new.diff(from_db, to_db) }

      it 'should be a no-op for the rename' do
        expect(subject[:rename_table]).to be_empty
        expect(subject[:add_table]).to be_empty
        expect(subject[:remove_table]).to be_empty
        expect(subject[:change_table]).to be_empty
      end
    end

    context 'when multiple tables claim the same renamed_from (ambiguous)' do
      let(:renamed_table1) do
        Convergence::Table.new('simple_table_a', renamed_from: 'simple_table').tap do |t|
          t.int('id', primary_key: true)
        end
      end
      let(:renamed_table2) do
        Convergence::Table.new('simple_table_b', renamed_from: 'simple_table').tap do |t|
          t.int('id', primary_key: true)
        end
      end
      let(:from_db) do
        { 'simple_table' => simple_table }
      end
      let(:to_db) do
        { 'simple_table_a' => renamed_table1, 'simple_table_b' => renamed_table2 }
      end

      it 'should raise an ArgumentError' do
        expect { Convergence::Diff.new.diff(from_db, to_db) }.to raise_error(ArgumentError)
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
            t.varchar('name', limit: 200, null: false)
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

      context 'all columns are renamed' do
        let(:table_to) do
          Convergence::Table.new('table1').tap do |t|
            t.int('id_rename', primary_key: true, renamed_from: 'id')
            t.varchar('name_rename', limit: 200, null: false, renamed_from: 'name')
          end
        end

        it 'should detect it as a change_table with rename_column, not a drop+add' do
          results = Convergence::Diff.new.diff({ 'table1' => table_from }, { 'table1' => table_to })
          expect(results[:add_table]).to be_empty
          expect(results[:remove_table]).to be_empty
          expect(results[:change_table]).not_to be_empty
          expect(results[:change_table]['table1'][:rename_column]).to eq('id' => 'id_rename', 'name' => 'name_rename')
        end
      end
    end
  end

  describe '#diff_table' do
    subject(:results) { Convergence::Diff.new(**diff_options).diff_table(table_from, table_to) }
    let(:diff_options) { {} }

    context 'change auto_increment table option' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.table_options = { auto_increment: 1 }
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.table_options = { auto_increment: 5000 }
        end
      end

      it 'detects the auto_increment change by default' do
        expect(results[:change_table_option][:auto_increment]).to eq(5000)
      end

      context 'when ignore_auto_increment is enabled' do
        let(:diff_options) { { ignore_auto_increment: true } }

        it 'ignores the auto_increment change' do
          expect(results[:change_table_option]).not_to have_key(:auto_increment)
        end
      end
    end

    context 'change column options' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
          t.datetime('created_at', default: -> { "CURRENT_TIMESTAMP" })
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 300, null: true, unsigned: true)     # option changed
          t.datetime('created_at', default: -> { "CURRENT_TIMESTAMP" }) # option[:default] not changed
        end
      end

      it do
        expect(results[:change_column]['name']).not_to be_nil
        expect(results[:change_column]['name'][:limit]).to eq('300')
        expect(results[:change_column]['name'][:null]).to eq('true')
        expect(results[:change_column]['name'][:unsigned]).to eq('true')
        expect(results[:change_column]['created_at']).to be_nil
      end
    end

    context 'change enum/set column values' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.enum('status', values: %w(Active Inactive))
        end
      end

      context 'when values are identical' do
        let(:table_to) do
          Convergence::Table.new('table1').tap do |t|
            t.int('id', primary_key: true)
            t.enum('status', values: %w(Active Inactive))
          end
        end

        it 'does not detect a change' do
          expect(results[:change_column]['status']).to be_nil
        end
      end

      context 'when only the letter case differs' do
        let(:table_to) do
          Convergence::Table.new('table1').tap do |t|
            t.int('id', primary_key: true)
            t.enum('status', values: %w(active inactive))
          end
        end

        it 'detects the change since values are case-sensitive' do
          expect(results[:change_column]['status']).not_to be_nil
          expect(results[:change_column]['status'][:values]).to eq('["active", "inactive"]')
        end
      end
    end

    context 'change column order' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.varchar('name', limit: 200, null: false)
          t.int('id', primary_key: true)
        end
      end

      it do
        expect(results[:change_column]['name']).to be_nil
        expect(results[:change_column]['id']).not_to be_nil
        expect(results[:change_column]['id'][:after]).to eq('name')
      end
    end

    context 'rename column' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('full_name', limit: 200, null: false, renamed_from: 'name')
        end
      end

      it 'should detect it as a rename, not remove+add' do
        expect(results[:rename_column]).to eq('name' => 'full_name')
        expect(results[:remove_column]).to be_empty
        expect(results[:add_column]).to be_empty
      end
    end

    context 'rename column together with an unrelated change on another column' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('full_name', limit: 300, null: false, renamed_from: 'name')
        end
      end

      it 'should detect only the rename, deferring the other change to the next apply pass' do
        expect(results[:rename_column]).to eq('name' => 'full_name')
        expect(results[:change_column]).to be_empty
      end
    end

    context 'rename the only column in a table' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('identifier', primary_key: true, renamed_from: 'id')
        end
      end

      it 'should not be misdetected as removing all columns' do
        expect(results[:rename_column]).to eq('id' => 'identifier')
        expect(results[:remove_column]).to be_empty
        expect(results[:add_column]).to be_empty
      end
    end

    context 'remove index' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)

          t.index('name')
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end

      it { expect(results[:remove_index].values.first.index_columns).to eq(['name']) }
    end

    context 'add index' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)

          t.index('name')
        end
      end

      it { expect(results[:add_index].values.first.index_columns).to eq(['name']) }
    end

    context 'remove foreign key' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)

          t.foreign_key('id', reference: 'ref_tables', reference_column: 'ref_id')
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end

      it { expect(results[:remove_foreign_key].values.first.from_columns).to eq(['id']) }
    end

    context 'add foreign key' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)

          t.foreign_key('id', reference: 'ref_tables', reference_column: 'ref_id')
        end
      end

      it { expect(results[:add_foreign_key].values.first.from_columns).to eq(['id']) }
    end

    context 'change table options' do
      let(:table_from) do
        Convergence::Table.new('table1').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end
      let(:table_to) do
        Convergence::Table.new('table1', engine: 'MyISAM').tap do |t|
          t.int('id', primary_key: true)
          t.varchar('name', limit: 200, null: false)
        end
      end

      it { expect(results[:change_table_option][:engine]).to eq('MyISAM') }
    end
  end
end
