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
create_table "dummy_table", engine: "MyISAM" do |t|
  t.int "id", limit: 11
  t.varchar "name", limit: 100, null: true, comment: "name"

  t.index "name", name: "idx_name"
  t.foreign_key "id", reference: "dummy_ref", reference_column: "id", name: "dummy_table_id_fk"
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
  end
end
