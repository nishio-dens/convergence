require 'spec_helper'

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
    dsl = <<-DSL
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
        dsl = <<-DSL
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
  end
end
