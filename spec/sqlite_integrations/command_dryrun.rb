require 'spec_helper'
require 'convergence/command/dryrun'

describe 'SQLite Command::Dryrun#execute' do
  def execute(dsl_path, extra_options = {})
    parse_option = {
      input: File.expand_path("#{File.dirname(__FILE__)}/../fixtures/sqlite/#{dsl_path}")
    }.merge(extra_options)
    Convergence::Command::Dryrun.new(parse_option, config: sqlite_settings).execute
  end

  describe 'add table' do
    let(:exec_dsl) { 'add_table.schema' }

    it 'should be output create table query' do
      result = execute(exec_dsl)
      expect(result).to be_include(%(# CREATE TABLE "dummies" (\n#   "id" INTEGER PRIMARY KEY AUTOINCREMENT\n# );))
    end
  end

  describe 'drop table' do
    let(:exec_dsl) { 'drop_table.schema' }

    it 'should be output drop table query' do
      result = execute(exec_dsl)
      expect(result).to be_include('DROP TABLE "paper_authors";')
    end

    context 'when safe_migration is enabled' do
      it 'should not output drop table query' do
        result = execute(exec_dsl, safe_migration: true)
        expect(result).not_to be_include('DROP TABLE "paper_authors";')
      end
    end
  end

  describe 'add columns' do
    let(:exec_dsl) { 'add_columns_to_paper.schema' }

    it 'should be output alter add column query' do
      result = execute(exec_dsl)
      expect(result).to be_include(%(# ALTER TABLE "papers" ADD COLUMN "subtitle" varchar;))
    end
  end

  describe 'remove columns' do
    let(:exec_dsl) { 'remove_columns_to_paper.schema' }

    it 'should be output alter drop column query' do
      result = execute(exec_dsl)
      expect(result).to be_include(%(# ALTER TABLE "papers" DROP COLUMN "description";))
    end
  end

  describe 'change columns' do
    let(:exec_dsl) { 'change_columns_to_paper.schema' }

    it 'should raise NotImplementedError since SQLite cannot ALTER a column in place' do
      expect { execute(exec_dsl) }.to raise_error(NotImplementedError, /does not support changing column/)
    end
  end

  describe 'drop foreign key' do
    let(:exec_dsl) { 'drop_foreign_key.schema' }

    it 'should raise NotImplementedError since SQLite cannot drop a foreign key in place' do
      expect { execute(exec_dsl) }.to raise_error(NotImplementedError, /does not support removing a foreign key/)
    end
  end
end
