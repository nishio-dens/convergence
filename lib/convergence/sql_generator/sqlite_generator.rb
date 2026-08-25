require 'convergence/sql_generator'

# SQLite's ALTER TABLE support is intentionally limited: it can add/drop columns
# and create/drop indexes, but it cannot change a column's type/null/default,
# nor add/remove a foreign key or primary key on an existing table. Doing any of
# those requires SQLite's official "rebuild the table" procedure (create a new
# table, copy the data over, drop the old one, rename), which this adapter does
# not implement yet -- it raises NotImplementedError instead of generating SQL
# that SQLite would reject.
class SQLGenerator::SqliteGenerator < SQLGenerator
  UNSUPPORTED_TYPES = [:enum, :set].freeze

  attr_reader :original_table

  def generate(to_table, delta, original_table, safe_migration: false)
    @original_table = original_table
    sqls = []
    sqls << change_table_sql(to_table, delta)
    sqls << (safe_migration ? [] : drop_table_sqls(delta))
    sqls << create_table_sqls(delta)
    sqls.reject!(&:empty?)
    sqls.join("\n")
  end

  private

  def change_table_sql(to_table, delta)
    change_table = delta[:change_table]
    results = []
    change_table.each do |table_name, table_delta|
      unless table_delta[:remove_foreign_key].empty?
        fail unsupported_alter_error(table_name, 'removing a foreign key')
      end
      unless table_delta[:add_foreign_key].empty?
        fail unsupported_alter_error(table_name, 'adding a foreign key')
      end
      unless table_delta[:change_column].empty?
        columns = table_delta[:change_column].keys.join(', ')
        fail unsupported_alter_error(table_name, "changing column(s) #{columns} (type/null/default/primary key)")
      end
      table_delta[:remove_index].each do |index_name, _index|
        results << alter_remove_index_sql(index_name)
      end
      unless table_delta[:remove_column].empty?
        results << alter_remove_columns_sql(table_name, table_delta[:remove_column].values)
      end
      unless table_delta[:add_column].empty?
        results << alter_add_columns_sql(table_name, table_delta[:add_column].values)
      end
      table_delta[:add_index].each do |_index_name, index|
        results << alter_add_index_sql(table_name, index)
      end
      # SQLite has no table-level options comparable to MySQL's engine/comment/
      # charset, so any detected change_table_option diff is silently ignored.
    end
    results << '' unless results.empty?
    results
  end

  def unsupported_alter_error(table_name, action)
    NotImplementedError.new(
      "SQLite adapter does not support #{action} on an existing table (`#{table_name}`) via ALTER TABLE. " \
      'This requires rebuilding the table (create new, copy data, drop old, rename), which is not supported yet.'
    )
  end

  def alter_add_columns_sql(table_name, columns)
    columns.map { |column| %(ALTER TABLE "#{table_name}" ADD COLUMN #{create_column_sql(column)};) }.join("\n")
  end

  def alter_remove_columns_sql(table_name, columns)
    columns.map { |column| %(ALTER TABLE "#{table_name}" DROP COLUMN "#{column.column_name}";) }.join("\n")
  end

  def alter_remove_index_sql(index_name)
    %(DROP INDEX "#{index_name}";)
  end

  def alter_add_index_sql(table_name, index)
    sql = 'CREATE'
    sql += ' UNIQUE' if index.options[:unique]
    sql += %( INDEX "#{index.index_name}" ON "#{table_name}" (#{quoted_index_columns(index).join(',')});)
    sql
  end

  def create_table_sqls(delta)
    delta[:add_table].map do |table_name, table|
      column_sql = (create_table_column_sql(table) << create_table_constraint_sql(table))
        .flatten
        .reject(&:empty?)
        .join(",\n  ")
      sql = <<-SQL
CREATE TABLE "#{table_name}" (
  #{column_sql}
);
      SQL
      index_sqls = table.indexes.values.map { |index| alter_add_index_sql(table_name, index) }
      ([sql.strip] + index_sqls).join("\n")
    end
  end

  def drop_table_sqls(delta)
    delta[:remove_table].map do |table_name, _|
      %(DROP TABLE "#{table_name}";)
    end
  end

  def create_table_column_sql(table)
    table.columns.values.map do |column|
      create_column_sql(column)
    end
  end

  def create_column_sql(column)
    fail NotImplementedError.new("#{column.type} is not supported on the SQLite adapter yet") if UNSUPPORTED_TYPES.include?(column.type)
    return %("#{column.column_name}" INTEGER PRIMARY KEY AUTOINCREMENT) if auto_increment?(column)
    sql = %("#{column.column_name}")
    sql += " #{sqlite_column_type(column)}"
    if column.options[:primary_key]
      sql += ' PRIMARY KEY'
    end
    sql += ' NOT NULL' unless column.options[:null]
    if column.options[:default]
      sql += " DEFAULT #{quote_default_expression(column.options[:default])}"
    end
    sql
  end

  def sqlite_column_type(column)
    type = column.type.to_s
    if column.type == :decimal && column.options[:precision] && column.options[:scale]
      "#{type}(#{column.options[:precision]}, #{column.options[:scale]})"
    elsif column.options[:limit] && !column.options[:limit].to_s.empty?
      "#{type}(#{column.options[:limit]})"
    else
      type
    end
  end

  def auto_increment?(column)
    extra = column.options[:extra]
    !extra.nil? && extra.to_s.upcase.include?('AUTO_INCREMENT')
  end

  # A single-column INTEGER PRIMARY KEY AUTOINCREMENT already declares itself as
  # the primary key inline, so it must not also appear in a table-level
  # PRIMARY KEY (...) clause.
  def create_table_constraint_sql(table)
    pkeys = table.columns.reject { |_k, v| auto_increment?(v) }.select { |_k, v| v.options[:primary_key] }
    foreign_keys = table.foreign_keys.values
    results = []
    unless pkeys.empty?
      results << %(PRIMARY KEY (#{pkeys.keys.map { |v| %("#{v}") }.join(',')}))
    end
    results << foreign_keys.map { |fk| foreign_key_constraint_sql(fk) }
    results
  end

  def foreign_key_constraint_sql(foreign_key)
    sql = %(CONSTRAINT "#{foreign_key.key_name}" FOREIGN KEY )
    sql += "(#{[foreign_key.from_columns].flatten.map { |v| %("#{v}") }.join(',')}) "
    sql += %(REFERENCES "#{foreign_key.to_table}" )
    sql += "(#{[foreign_key.to_columns].flatten.map { |v| %("#{v}") }.join(',')})"
    sql
  end

  def quoted_index_columns(index)
    [index.index_columns].flatten.map { |v| %("#{v}") }
  end

  def quote_default_expression(value)
    if value.is_a?(Proc)
      value.call
    else
      %('#{value.to_s.gsub("'", "''")}')
    end
  end
end
