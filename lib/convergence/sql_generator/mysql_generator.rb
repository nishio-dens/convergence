class SQLGenerator::MysqlGenerator < SQLGenerator
  OPTION_MAPPING = {
    engine: 'ENGINE',
    row_format: 'ROW_FORMAT',
    default_charset: 'DEFAULT CHARACTER SET',
    collate: 'COLLATE',
    comment: 'COMMENT'
  }
  QUOTE_OPTION = [:comment]

  attr_reader :original_table

  def generate(to_table, delta, original_table)
    @original_table = original_table
    sqls = []
    sqls << change_table_sql(to_table, delta)
    sqls << ['']
    sqls << create_table_sqls(delta)
    sqls << drop_table_sqls(delta)
    sqls.join("\n")
  end

  private

  # FIXME: multiple pk change not supported yet
  def change_table_sql(to_table, delta)
    change_table = delta[:change_table]
    results = []
    change_table.each do |table_name, table_delta|
      table_delta[:remove_foreign_key].each do |index_name, _foreign_key|
        results << alter_remove_foreign_key_sql(table_name, index_name)
      end
      table_delta[:remove_index].each do |index_name, _index|
        results << alter_remove_index_sql(table_name, index_name)
      end
      table_delta[:remove_column].each do |_column_name, column|
        results << alter_remove_column_sql(table_name, column)
      end
      table_delta[:add_column].each do |_column_name, column|
        results << alter_add_column_sql(table_name, column)
      end
      table_delta[:change_column].each do |column_name, column|
        results << alter_change_column_sql(table_name, column_name, column, to_table)
      end
      table_delta[:add_index].each do |_index_name, index|
        results << alter_add_index_sql(table_name, index)
      end
      table_delta[:add_foreign_key].each do |_index_name, foreign_key|
        results << alter_add_foreign_key_sql(table_name, foreign_key)
      end
      unless table_delta[:change_table_option].empty?
        results << alter_change_table_sql(table_name, table_delta[:change_table_option])
      end
    end
    results
  end

  def alter_add_column_sql(table_name, column)
    %(ALTER TABLE `#{table_name}` ADD COLUMN #{create_column_sql(column, output_primary_key: true)};)
  end

  def alter_remove_column_sql(table_name, column)
    %(ALTER TABLE `#{table_name}` DROP COLUMN `#{column.column_name}`;)
  end

  def alter_change_column_sql(table_name, column_name, change_column_option, to_table)
    column = to_table[table_name].columns[column_name]
    column.options.merge!(after: change_column_option[:after]) unless change_column_option[:after].nil?
    sql = ""
    original_column = original_table[table_name].columns[column_name]
    if original_column.options[:primary_key]
      extra = original_column.options[:extra]
      if extra && extra.upcase.include?('AUTO_INCREMENT')
        sql += %(ALTER TABLE `#{table_name}` MODIFY COLUMN #{create_column_sql(original_column, output_auto_increment: false)};\n)
      end
      sql += %(ALTER TABLE `#{table_name}` DROP PRIMARY KEY;\n)
    end
    sql += %(ALTER TABLE `#{table_name}` MODIFY COLUMN #{create_column_sql(column, output_primary_key: true)};)
    sql
  end

  def alter_change_table_sql(table_name, change_table_option)
    sql = "ALTER TABLE `#{table_name}`"
    change_table_option.each do |key, value|
      if QUOTE_OPTION.include?(key)
        sql += " #{OPTION_MAPPING[key]}='#{value}'"
      else
        sql += " #{OPTION_MAPPING[key]}=#{value}"
      end
    end
    sql += ';'
    sql
  end

  def alter_remove_index_sql(table_name, index_name)
    %(DROP INDEX `#{index_name}` ON `#{table_name}`;)
  end

  def alter_add_index_sql(table_name, index)
    sql = 'CREATE'
    sql += ' UNIQUE' if index.options[:unique]
    sql += " INDEX `#{index.index_name}` ON `#{table_name}`(#{index.quoted_columns.join(',')});"
    sql
  end

  def alter_remove_foreign_key_sql(table_name, index_name)
    sql = %(ALTER TABLE `#{table_name}` DROP FOREIGN KEY `#{index_name}`;\n)
    sql += alter_remove_index_sql(table_name, index_name)
    sql
  end

  def alter_add_foreign_key_sql(table_name, foreign_key)
    sql = %(ALTER TABLE `#{table_name}` ADD CONSTRAINT `#{foreign_key.key_name}` FOREIGN KEY )
    sql += "(#{[foreign_key.from_columns].join(',')}) REFERENCES `#{foreign_key.to_table}`"
    sql += "(#{[foreign_key.to_columns].join(',')});"
    sql
  end

  def create_table_sqls(delta)
    delta[:add_table].map do |table_name, table|
      column_sql = (create_table_column_sql(table) << create_table_index_sql(table))
        .flatten
        .reject(&:empty?)
        .join(",\n  ")
      <<-SQL
CREATE TABLE `#{table_name}` (
  #{column_sql}
) #{create_table_option_sql(table)};
      SQL
    end
  end

  def drop_table_sqls(delta)
    delta[:remove_table].map do |table_name, _|
      <<-SQL
DROP TABLE `#{table_name}`;
      SQL
    end
  end

  def create_table_column_sql(table)
    table.columns.values.map do |column|
      create_column_sql(column)
    end
  end

  def create_column_sql(column, output_primary_key: false, output_auto_increment: true)
    sql = "`#{column.column_name}`"
    sql += " #{column.type}"
    sql += "(#{column.options[:limit]})" unless column.options[:limit].nil?
    if column.options[:precision] && column.options[:scale]
      sql += "(#{column.options[:precision]}, #{column.options[:scale]})"
    end
    if column.options[:character_set]
      sql += " CHARACTER SET #{column.options[:character_set]}"
    end
    if column.options[:collate]
      sql += " COLLATE #{column.options[:collate]}"
    end
    if column.options[:null]
      sql += ' DEFAULT NULL' unless column.options[:default]
    else
      sql += ' NOT NULL'
    end
    if column.options[:primary_key] && output_primary_key
      sql += ' PRIMARY KEY'
    end
    if column.options[:default]
      sql += " DEFAULT '#{column.options[:default]}'"
    end
    if column.options[:comment]
      sql += " COMMENT '#{column.options[:comment]}'"
    end
    if column.options[:extra]
      if output_auto_increment
        sql += " #{column.options[:extra].upcase}"
      else
        sql += " #{column.options[:extra].upcase.sub('AUTO_INCREMENT', '')}"
      end
    end
    if column.options.keys.include?(:after)
      if column.options[:after].nil?
        sql += ' FIRST'
      else
        sql += " AFTER `#{column.options[:after]}`"
      end
    end
    sql
  end

  def create_table_index_sql(table)
    pkeys = table.columns.select { |_k, v| v.options[:primary_key] }
    unique_keys = table.indexes.values.select { |v| v.options[:unique] }
    index_keys = table.indexes.values.reject { |v| v.options[:unique] }
    foreign_keys = table.foreign_keys.values
    results = []
    unless pkeys.empty?
      results << %(PRIMARY KEY (#{pkeys.keys.map { |v| "`#{v}`" }.join(',')}))
    end
    results << unique_keys.map do |uk|
      %(UNIQUE KEY `#{uk.index_name}` (#{uk.index_columns.map { |v| "`#{v}`" }.join(',')}))
    end
    results << index_keys.map do |ik|
      %(KEY `#{ik.index_name}` (#{ik.index_columns.map { |v| "`#{v}`" }.join(',')}))
    end
    results << foreign_keys.map do |fk|
      sql = %(CONSTRAINT `#{fk.key_name}` FOREIGN KEY)
      sql += %( (#{[fk.from_columns].flatten.map { |v| "`#{v}`" }.join(',')}))
      sql += %( REFERENCES `#{fk.to_table}` (#{[fk.to_columns].flatten.map { |v| "`#{v}`" }.join(',')}))
      sql
    end
    results
  end

  def create_table_option_sql(table)
    table.table_options.map do |k, v|
      key = OPTION_MAPPING[k] || k.to_s.upcase
      if QUOTE_OPTION.include?(k)
        "#{key}=\"#{v}\""
      else
        "#{key}=#{v}"
      end
    end.join(' ')
  end
end
