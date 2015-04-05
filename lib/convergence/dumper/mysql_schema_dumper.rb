require 'mysql2'
class Convergence::Dumper::MysqlSchemaDumper
  def initialize(connector)
    @connector = connector
    @target_database = connector.config.database
    @tables = {}
  end

  def dump
    table_definitions = select_table_definitions(@target_database)
    column_definitions = select_column_definitions(@target_database).group_by { |r| r['TABLE_NAME'] }
    index_definitions = select_index_definitions(@target_database).group_by { |r| r['TABLE_NAME'] }
    table_definitions.map { |r| r['TABLE_NAME'] }.each do |table_name|
      table = Convergence::Table.new(table_name)
      parse_table_options(table, table_definitions.find { |r| r['TABLE_NAME'] == table_name })
      parse_columns(table, column_definitions[table_name])
      parse_indexes(table, index_definitions[table_name])
      @tables[table_name] = table
    end
    @tables
  end

  private

  def mysql
    @connector.schema_client
  end

  def select_table_definitions(database_name)
    mysql.query("
      SELECT
        *
      FROM
        TABLES
      INNER JOIN
        COLLATION_CHARACTER_SET_APPLICABILITY CCSA
      ON
        TABLES.TABLE_COLLATION = CCSA.COLLATION_NAME
      WHERE
        TABLE_SCHEMA = '#{mysql.escape(database_name)}'
      ORDER BY
        TABLE_NAME
    ")
  end

  def select_column_definitions(database_name)
    mysql.query("
      SELECT * FROM COLUMNS
      WHERE TABLE_SCHEMA = '#{mysql.escape(database_name)}'
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    ")
  end

  def select_index_definitions(database_name)
    mysql.query("
      SELECT
        DISTINCT S.TABLE_NAME, S.COLUMN_NAME, S.NON_UNIQUE, S.INDEX_NAME, S.SEQ_IN_INDEX, S.INDEX_TYPE,
        IF(TC.CONSTRAINT_TYPE IS NULL, 'INDEX', TC.CONSTRAINT_TYPE) CONSTRAINT_TYPE,
        KCU.REFERENCED_TABLE_NAME, KCU.REFERENCED_COLUMN_NAME
      FROM
        STATISTICS S
      LEFT OUTER JOIN
        TABLE_CONSTRAINTS TC
      ON
        TC.TABLE_SCHEMA = S.TABLE_SCHEMA
        AND TC.TABLE_NAME = S.TABLE_NAME
        AND TC.CONSTRAINT_NAME = S.INDEX_NAME
      LEFT OUTER JOIN
        KEY_COLUMN_USAGE KCU
      ON
        KCU.CONSTRAINT_SCHEMA = S.TABLE_SCHEMA
        AND KCU.TABLE_NAME = S.TABLE_NAME
        AND KCU.CONSTRAINT_NAME = TC.CONSTRAINT_NAME
      WHERE
        S.TABLE_SCHEMA = '#{mysql.escape(database_name)}'
      ORDER BY
        S.TABLE_NAME, S.INDEX_NAME, S.SEQ_IN_INDEX
    ")
  end

  def parse_table_options(table, table_option)
    option = {}
    option.merge!(engine: table_option['ENGINE'])
    row_format = table_option['CREATE_OPTIONS'].scan(/=(.*)/).flatten[0] || table_option['ROW_FORMAT']
    option.merge!(row_format: row_format)
    option.merge!(default_charset: table_option['CHARACTER_SET_NAME'])
    option.merge!(collate: table_option['TABLE_COLLATION'])
    option.merge!(comment: table_option['TABLE_COMMENT'])
    table.table_options = option
  end

  def parse_columns(table, columns)
    columns.each do |column|
      data_type, column_name, options = parse_column(column)
      table.send(data_type, column_name, options)
    end
  end

  def parse_column(column)
    data_type = column['DATA_TYPE']
    column_name = column['COLUMN_NAME']
    options = { null: column['IS_NULLABLE'] == 'YES' ? true : false }
    options.merge!(default: column['COLUMN_DEFAULT']) unless column['COLUMN_DEFAULT'].nil?
    options.merge!(character_set: column['CHARACTER_SET_NAME']) unless column['CHARACTER_SET_NAME'].nil?
    options.merge!(collate: column['COLLATION_NAME']) unless column['COLLATION_NAME'].nil?
    column_type = column['COLUMN_TYPE']
    if data_type == 'enum' || data_type == 'set'
      # TODO: implement
    elsif data_type == 'decimal'
      precision, scale = column_type.scan(/\d+/)
      options.merge!(precision: precision, scale: scale)
    else
      limit = column_type.scan(/\d+/)[0]
      options.merge!(limit: limit) unless limit.nil?
    end
    options.merge!(extra: column['EXTRA']) unless column['EXTRA'].empty?
    options.merge!(comment: column['COLUMN_COMMENT']) unless column['COLUMN_COMMENT'].empty?
    [data_type, column_name, options]
  end

  def parse_indexes(table, table_indexes)
    return if table_indexes.nil?
    table_indexes.group_by { |r| r['INDEX_NAME'] }.each do |index_name, indexes|
      type = indexes.first['CONSTRAINT_TYPE']
      columns = indexes.map { |v| v['COLUMN_NAME'] }
      case type
      when 'PRIMARY KEY'
        indexes.map { |r| r['COLUMN_NAME'] }.each do |column|
          options = { primary_key: true }.merge(table.columns[column].options)
          table.columns[column].options = options
        end
      when 'INDEX', 'UNIQUE'
        options = { name: index_name, type: indexes.first['INDEX_TYPE'] }
        options.merge!(unique: true) if type == 'UNIQUE'
        table.index(columns, options)
      when 'FOREIGN KEY'
        to_table = indexes.first['REFERENCED_TABLE_NAME']
        to_columns = indexes.map { |v| v['REFERENCED_COLUMN_NAME'] }
        options = {
          reference: to_table,
          reference_column: to_columns,
          name: index_name
        }
        table.foreign_key(columns, options)
      else
        fail NotImplementedError.new('Unknown index type')
      end
    end
  end
end
