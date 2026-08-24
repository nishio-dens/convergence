require 'convergence/sql_generator'

class SQLGenerator::PostgresGenerator < SQLGenerator
  # Convergence's DSL type names follow MySQL terminology (kept for cross-adapter DSL
  # compatibility). Map them to their closest native PostgreSQL type.
  TYPE_MAPPING = {
    tinyint: 'smallint',
    smallint: 'smallint',
    mediumint: 'integer',
    int: 'integer',
    bigint: 'bigint',
    float: 'real',
    double: 'double precision',
    decimal: 'decimal',
    char: 'char',
    varchar: 'varchar',
    tinyblob: 'bytea',
    blob: 'bytea',
    mediumblob: 'bytea',
    longblob: 'bytea',
    tinytext: 'text',
    text: 'text',
    mediumtext: 'text',
    longtext: 'text',
    date: 'date',
    time: 'time',
    datetime: 'timestamp',
    timestamp: 'timestamp',
    year: 'integer',
    json: 'jsonb'
  }.freeze
  TYPES_WITH_LIMIT = [:char, :varchar].freeze
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

  # FIXME: multiple pk change not supported yet
  def change_table_sql(to_table, delta)
    change_table = delta[:change_table]
    results = []
    change_table.each do |table_name, table_delta|
      unless table_delta[:remove_foreign_key].empty?
        results << alter_remove_foreign_keys_sql(table_name, table_delta[:remove_foreign_key].keys)
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
      table_delta[:change_column].each do |column_name, column|
        results << alter_change_column_sql(table_name, column_name, column, to_table)
      end
      table_delta[:add_index].each do |_index_name, index|
        results << alter_add_index_sql(table_name, index)
      end
      unless table_delta[:add_foreign_key].empty?
        results << alter_add_foreign_keys_sql(table_name, table_delta[:add_foreign_key].values)
      end
      unless table_delta[:change_table_option].empty?
        results << alter_change_table_sql(table_name, table_delta[:change_table_option])
      end
    end
    results << '' unless results.empty?
    results
  end

  def alter_add_columns_sql(table_name, columns)
    add_column_sqls = columns.map { |column| %(ALTER TABLE "#{table_name}" ADD COLUMN #{create_column_sql(column, output_primary_key: true)};) }
    comment_sqls = columns.map { |column| comment_on_column_sql(table_name, column) }.compact
    (add_column_sqls + comment_sqls).join("\n")
  end

  def alter_remove_columns_sql(table_name, columns)
    columns.map { |column| %(ALTER TABLE "#{table_name}" DROP COLUMN "#{column.column_name}";) }.join("\n")
  end

  def alter_change_column_sql(table_name, column_name, change_column_option, to_table)
    column = to_table[table_name].columns[column_name]
    column.options.merge!(after: change_column_option[:after]) unless change_column_option[:after].nil?
    sqls = []
    sqls << %(ALTER TABLE "#{table_name}" ALTER COLUMN "#{column_name}" TYPE #{postgres_column_type(column)} USING "#{column_name}"::#{postgres_column_type(column)};)
    if column.options[:null]
      sqls << %(ALTER TABLE "#{table_name}" ALTER COLUMN "#{column_name}" DROP NOT NULL;)
    else
      sqls << %(ALTER TABLE "#{table_name}" ALTER COLUMN "#{column_name}" SET NOT NULL;)
    end
    if column.options[:default]
      sqls << %(ALTER TABLE "#{table_name}" ALTER COLUMN "#{column_name}" SET DEFAULT #{quote_default_expression(column.options[:default])};)
    else
      sqls << %(ALTER TABLE "#{table_name}" ALTER COLUMN "#{column_name}" DROP DEFAULT;)
    end
    comment_sql = comment_on_column_sql(table_name, column)
    sqls << comment_sql unless comment_sql.nil?
    sqls.join("\n")
  end

  def alter_change_table_sql(table_name, change_table_option)
    return '' unless change_table_option.key?(:comment)
    %(COMMENT ON TABLE "#{table_name}" IS '#{escape_quote(change_table_option[:comment])}';)
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

  def alter_remove_foreign_keys_sql(table_name, index_names)
    index_names.map { |index_name| %(ALTER TABLE "#{table_name}" DROP CONSTRAINT "#{index_name}";) }.join("\n")
  end

  def alter_add_foreign_keys_sql(table_name, foreign_keys)
    foreign_keys.map { |foreign_key| %(ALTER TABLE "#{table_name}" ADD #{foreign_key_constraint_sql(foreign_key)};) }.join("\n")
  end

  def foreign_key_constraint_sql(foreign_key)
    sql = %(CONSTRAINT "#{foreign_key.key_name}" FOREIGN KEY )
    sql += "(#{[foreign_key.from_columns].flatten.map { |v| %("#{v}") }.join(',')}) "
    sql += %(REFERENCES "#{foreign_key.to_table}" )
    sql += "(#{[foreign_key.to_columns].flatten.map { |v| %("#{v}") }.join(',')})"
    sql
  end

  def create_table_sqls(delta)
    delta[:add_table].map do |table_name, table|
      column_sql = (create_table_column_sql(table) << create_table_index_sql(table))
        .flatten
        .reject(&:empty?)
        .join(",\n  ")
      sql = <<-SQL
CREATE TABLE "#{table_name}" (
  #{column_sql}
);
      SQL
      sql = sql.strip
      index_sqls = table.indexes.values.map { |index| alter_add_index_sql(table_name, index) }
      comment_sqls = create_table_comment_sqls(table_name, table)
      ([sql] + index_sqls + comment_sqls).join("\n")
    end
  end

  def create_table_comment_sqls(table_name, table)
    sqls = []
    if table.table_options[:comment] && !table.table_options[:comment].to_s.empty?
      sqls << %(COMMENT ON TABLE "#{table_name}" IS '#{escape_quote(table.table_options[:comment])}';)
    end
    table.columns.values.each do |column|
      comment_sql = comment_on_column_sql(table_name, column)
      sqls << comment_sql unless comment_sql.nil?
    end
    sqls
  end

  def comment_on_column_sql(table_name, column)
    return nil if column.options[:comment].nil? || column.options[:comment].to_s.empty?
    %(COMMENT ON COLUMN "#{table_name}"."#{column.column_name}" IS '#{escape_quote(column.options[:comment])}';)
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

  def create_column_sql(column, output_primary_key: false, output_identity: true)
    fail NotImplementedError.new("#{column.type} is not supported on PostgreSQL adapter yet") if UNSUPPORTED_TYPES.include?(column.type)
    sql = %("#{column.column_name}")
    sql += " #{postgres_column_type(column)}"
    if column.options[:null]
      sql += ' DEFAULT NULL' unless column.options[:default]
    else
      sql += ' NOT NULL'
    end
    if column.options[:primary_key] && output_primary_key
      sql += ' PRIMARY KEY'
    end
    if column.options[:default]
      sql += " DEFAULT #{quote_default_expression(column.options[:default])}"
    end
    if auto_increment?(column) && output_identity
      sql += ' GENERATED BY DEFAULT AS IDENTITY'
    end
    sql
  end

  def postgres_column_type(column)
    type = TYPE_MAPPING[column.type] || column.type.to_s
    if TYPES_WITH_LIMIT.include?(column.type) && column.options[:limit]
      "#{type}(#{column.options[:limit]})"
    elsif column.type == :decimal && column.options[:precision] && column.options[:scale]
      "#{type}(#{column.options[:precision]}, #{column.options[:scale]})"
    else
      type
    end
  end

  def auto_increment?(column)
    extra = column.options[:extra]
    !extra.nil? && extra.to_s.upcase.include?('AUTO_INCREMENT')
  end

  def create_table_index_sql(table)
    pkeys = table.columns.select { |_k, v| v.options[:primary_key] }
    foreign_keys = table.foreign_keys.values
    results = []
    unless pkeys.empty?
      results << %(PRIMARY KEY (#{pkeys.keys.map { |v| %("#{v}") }.join(',')}))
    end
    results << foreign_keys.map { |fk| foreign_key_constraint_sql(fk) }
    results
  end

  def quoted_index_columns(index)
    [index.index_columns].flatten.map { |v| %("#{v}") }
  end

  def escape_quote(value)
    value.to_s.gsub("'", "''")
  end

  def quote_default_expression(value)
    if value.is_a?(Proc)
      value.call
    else
      %('#{escape_quote(value)}')
    end
  end
end
