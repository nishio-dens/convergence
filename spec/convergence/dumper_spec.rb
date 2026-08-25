require 'spec_helper'
require 'convergence/dumper'
require 'convergence/table'

describe Convergence::Dumper do
  let(:table1) do
    Convergence::Table.new('dummy_table', engine: 'MyISAM').tap do |t|
      t.int :id, limit: 11
      t.varchar :name, limit: 100, null: true, comment: 'name'

      t.index :name, name: 'idx_name'
      t.foreign_key :id, reference: 'dummy_ref', reference_column: :id
    end
  end
  let(:table1_dsl) do
    dsl = <<~DSL
      create_table :dummy_table, engine: "MyISAM" do |t|
        t.int :id, limit: 11
        t.varchar :name, limit: 100, null: true, comment: "name"

        t.index :name, name: "idx_name"
        t.foreign_key :id, reference: :dummy_ref, reference_column: :id, name: "dummy_table_id_fk"
      end
    DSL
    dsl.strip
  end

  describe '#dump_dsl' do
    it 'should be able to dump tables dsl' do
      tables = { 'dummy_table' => table1 }
      dsl = Convergence::Dumper.new.dump_dsl(tables)
      expect(dsl).to eq(table1_dsl)
    end
  end

  describe '#dump_table_dsl' do
    it 'should be able to dump dsl' do
      dsl = Convergence::Dumper.new.dump_table_dsl(table1)
      expect(dsl).to eq(table1_dsl)
    end

    context "when MySQL identifiers that require quotes in Ruby symbol syntax" do
      let(:table1) do
        Convergence::Table.new('dummy-table', engine: 'MyISAM').tap do |t|
          t.int :id, limit: 11
          t.varchar :"column-1", limit: 100, null: true, comment: 'column 1'

          t.index :"column-1", name: 'idx_column-1'
          t.foreign_key :"column-1", reference: 'dummy-ref', reference_column: :"dummy-column"
        end
      end

      let(:table1_dsl) do
        dsl = <<~DSL
          create_table :"dummy-table", engine: "MyISAM" do |t|
            t.int :id, limit: 11
            t.varchar :"column-1", limit: 100, null: true, comment: "column 1"

            t.index :"column-1", name: "idx_column-1"
            t.foreign_key :"column-1", reference: :"dummy-ref", reference_column: :"dummy-column", name: "dummy-table_column-1_fk"
          end
        DSL
        dsl.strip
      end

      it 'should be able to dump dsl' do
        dsl = Convergence::Dumper.new.dump_table_dsl(table1)
        expect(dsl).to eq(table1_dsl)
      end
    end

    context "when the table column has default option with proc" do
      let(:table1) do
        Convergence::Table.new('dummy_table').tap do |t|
          t.int :edition_number, default: 0
          t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
        end
      end

      let(:table1_dsl) do
        dsl = <<~DSL
          create_table :dummy_table do |t|
            t.int :edition_number, default: 0
            t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
          end
        DSL
        dsl.strip
      end

      it 'should be able to dump dsl' do
        dsl = Convergence::Dumper.new.dump_table_dsl(table1)
        expect(dsl).to eq(table1_dsl)
      end
    end
  end

  describe '#dump_rails_migration' do
    let(:table1) do
      Convergence::Table.new('dummy_table', engine: 'MyISAM').tap do |t|
        t.int :id, primary_key: true, extra: 'auto_increment'
        t.varchar :name, limit: 100, null: true, comment: 'name'
        t.datetime :created_at, null: false
        t.datetime :updated_at, null: false

        t.index :name, name: 'idx_name'
        t.foreign_key :id, reference: 'dummy_ref', reference_column: :id
      end
    end

    let(:migration_dsl) do
      dsl = <<~DSL
        class DummyMigration < ActiveRecord::Migration[7.0]
          def change
            create_table :dummy_table do |t|
              t.string :name, limit: 100, null: true, comment: "name"
              t.timestamps null: false
              t.index :name, name: "idx_name"
              t.foreign_key :dummy_ref, column: :id, name: "dummy_table_id_fk"
            end
          end
        end
      DSL
      dsl.strip
    end

    it 'omits the implicit auto-increment id column' do
      migration = Convergence::Dumper.new.dump_rails_migration({ 'dummy_table' => table1 }, 'DummyMigration')
      expect(migration).to eq(migration_dsl)
    end

    it 'collapses created_at/updated_at into t.timestamps' do
      migration = Convergence::Dumper.new.dump_rails_migration({ 'dummy_table' => table1 }, 'DummyMigration')
      expect(migration).to be_include('t.timestamps null: false')
      expect(migration).not_to be_include('t.datetime :created_at')
    end

    context 'when the column is a MySQL tinyint(1) boolean' do
      let(:table1) do
        Convergence::Table.new('dummy_table').tap do |t|
          t.boolean :active, default: true
        end
      end

      it 'maps it to a native boolean column' do
        migration = Convergence::Dumper.new.dump_rails_migration({ 'dummy_table' => table1 }, 'DummyMigration')
        expect(migration).to be_include('t.boolean :active, default: true')
      end
    end

    context 'when created_at/updated_at have mismatched null options' do
      let(:table1) do
        Convergence::Table.new('dummy_table').tap do |t|
          t.datetime :created_at, null: false
          t.datetime :updated_at, null: true
        end
      end

      it 'keeps them as separate columns instead of collapsing into t.timestamps' do
        migration = Convergence::Dumper.new.dump_rails_migration({ 'dummy_table' => table1 }, 'DummyMigration')
        expect(migration).not_to be_include('t.timestamps')
        expect(migration).to be_include('t.datetime :created_at, null: false')
        expect(migration).to be_include('t.datetime :updated_at, null: true')
      end
    end
  end
end
