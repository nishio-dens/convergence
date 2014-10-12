require 'diffy'

class Convergence::PrettyDiff
  def initialize(from_tables, to_tables)
    @from_tables = from_tables
    @to_tables = to_tables
  end

  def output
    diff = Convergence::Diff.new.diff(@from_tables, @to_tables)
    add_tables = diff[:add_table].keys
    remove_tables = diff[:remove_table].keys
    change_tables = diff[:change_table].keys

    results = ''
    add_tables.each do |table_name|
      results += diff_add_table(table_name)
      results += "\n\n"
    end
    remove_tables.each do |table_name|
      results += diff_remove_table(table_name)
      results += "\n\n"
    end
    change_tables.each do |table_name|
      results += diff_change_table(table_name)
    end
    results
  end

  private

  def diff_add_table(table_name)
    Convergence::Dumper
      .new
      .dump_table_dsl(@to_tables[table_name])
      .split("\n")
      .map { |v| "+ #{v}" }
      .join("\n")
  end

  def diff_remove_table(table_name)
    Convergence::Dumper
      .new
      .dump_table_dsl(@from_tables[table_name])
      .split("\n")
      .map { |v| "- #{v}" }
      .join("\n")
  end

  def diff_change_table(table_name)
    from = Convergence::Dumper.new.dump_table_dsl(@from_tables[table_name]) + "\n"
    to = Convergence::Dumper.new.dump_table_dsl(@to_tables[table_name]) + "\n"
    Diffy::Diff.new(from, to).to_s
  end
end
