require 'spec_helper'
require 'convergence/command/dryrun'

describe 'Command::Dryrun#execute' do
  def execute(dsl_path, extra_options = {})
    parse_option = {
      input: File.expand_path("#{File.dirname(__FILE__)}/../fixtures/#{dsl_path}")
    }.merge(extra_options)
    Convergence::Command::Dryrun.new(parse_option, config: mysql_settings).execute
  end

  describe 'change table options' do
    let(:exec_dsl) { 'change_table_comment_to_paper.schema' }

    it 'should be output alter table query' do
      result = execute(exec_dsl)
      expect(result).to be_include("# ALTER TABLE `authors` COMMENT='Author Table';")
    end
  end

  describe 'add table' do
    let(:exec_dsl) { 'add_table.schema' }
    let(:expect_query) do
      q = <<-QUERY
# CREATE TABLE `dummies` (
#   `id` int(11) NOT NULL COMMENT 'Hello Convergence' AUTO_INCREMENT,
#   PRIMARY KEY (`id`)
# ) ENGINE=InnoDB ROW_FORMAT=Compact DEFAULT CHARACTER SET=utf8 COMMENT="Dummy Table" COLLATE=utf8_general_ci
      QUERY
      q.strip
    end
    it 'should be output create table query' do
      result = execute(exec_dsl)
      expect(result).to be_include(expect_query)
    end
  end

  describe 'add table with enum/set columns' do
    let(:exec_dsl) { 'add_table_with_enum_set.schema' }
    let(:expect_query) do
      q = <<-QUERY
# CREATE TABLE `enum_set_dummies` (
#   `id` int(11) NOT NULL AUTO_INCREMENT,
#   `status` enum('active','inactive','pending') CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL DEFAULT 'active',
#   `flags` set('a','b','c') CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
#   PRIMARY KEY (`id`)
# ) ENGINE=InnoDB ROW_FORMAT=Compact DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci
      QUERY
      q.strip
    end
    it 'should be output create table query with quoted enum/set values' do
      result = execute(exec_dsl)
      expect(result).to be_include(expect_query)
    end
  end

  describe 'drop table' do
    let(:exec_dsl) { 'drop_table.schema' }

    it 'should be output drop table query' do
      result = execute(exec_dsl)
      expect(result).to be_include('DROP TABLE `paper_authors`')
    end

    context 'when safe_migration is enabled' do
      it 'should not output drop table query' do
        result = execute(exec_dsl, safe_migration: true)
        expect(result).not_to be_include('DROP TABLE `paper_authors`')
      end
    end
  end

  describe 'execute raw sql' do
    let(:exec_dsl) { 'execute_raw_sql.schema' }

    it 'should be output the raw sql statement after the generated schema changes' do
      result = execute(exec_dsl)
      expect(result).to be_include('# UPDATE authors SET age = 0 WHERE age IS NULL;')
    end
  end

  describe 'add columns' do
    let(:exec_dsl) { 'add_columns_to_paper.schema' }

    it 'should be output alter add column query' do
      result = execute(exec_dsl)
      expect(result).to be_include("# ALTER TABLE `authors`\n#   ADD COLUMN `add_column` varchar(110) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL AFTER `name`;")
    end
  end

  describe 'remove columns' do
    let(:exec_dsl) { 'remove_columns_to_paper.schema' }

    it 'should be output alter drop column query' do
      result = execute(exec_dsl)
      expect(result).to be_include("# ALTER TABLE `authors`\n#   DROP COLUMN `name`;")
    end
  end

  describe 'change columns' do
    describe 'change comment' do
      let(:exec_dsl) { 'change_comment_columns_to_paper.schema' }

      it 'should be output alter table column query' do
        result = execute(exec_dsl)
        expect(result).to be_include("# ALTER TABLE `authors` MODIFY COLUMN `created_at` datetime DEFAULT NULL COMMENT 'Created At';")
      end
    end
  end

  describe 'rename column' do
    let(:exec_dsl) { 'rename_column_to_author.schema' }

    it 'should be output rename column query, not drop+add' do
      result = execute(exec_dsl)
      expect(result).to be_include('# ALTER TABLE `authors` RENAME COLUMN `name` TO `full_name`;')
      expect(result).not_to be_include('DROP COLUMN `name`')
      expect(result).not_to be_include('ADD COLUMN `full_name`')
    end
  end

  describe 'rename table' do
    let(:exec_dsl) { 'rename_table.schema' }

    it 'should be output rename table query, not drop+add' do
      result = execute(exec_dsl)
      expect(result).to be_include('# ALTER TABLE `paper_authors` RENAME TO `paper_author_links`;')
      expect(result).not_to be_include('DROP TABLE `paper_authors`')
      expect(result).not_to be_include('CREATE TABLE `paper_author_links`')
    end
  end

  describe 'auto increment' do
    describe 'create table with auto increment option' do
      let(:exec_dsl) { 'add_table.schema' }
      let(:expected_query) do
      q = <<-QUERY
# CREATE TABLE `dummies2` (
#   `id` int(11) NOT NULL AUTO_INCREMENT,
#   PRIMARY KEY (`id`)
# ) ENGINE=InnoDB ROW_FORMAT=Compact DEFAULT CHARACTER SET=utf8 AUTO_INCREMENT=1000 COLLATE=utf8_general_ci
      QUERY
      q.strip
      end

      it 'should be create table with auto increment options' do
        result = execute(exec_dsl)
        expect(result).to be_include(expected_query)
      end
    end
  end
end
