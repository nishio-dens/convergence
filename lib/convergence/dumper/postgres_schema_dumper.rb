# FIXME: fix something for postgres
class Convergence::Dumper::PostgresSchemaDumper
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

  def postgres
    @connector.schema_client
  end

  def select_table_definitions(database_name)
    postgres.query("
      SELECT
        *
      FROM
        TABLES
      INNER JOIN
        COLLATION_CHARACTER_SET_APPLICABILITY CCSA
      ON
        TABLES.TABLE_COLLATION = CCSA.COLLATION_NAME
      WHERE
        TABLE_SCHEMA = '#{postgres.escape(database_name)}'
      ORDER BY
        TABLE_NAME
    ")
  end

  def select_column_definitions(database_name)
    postgres.query("
      SELECT * FROM COLUMNS
      WHERE TABLE_SCHEMA = '#{postgres.escape(database_name)}'
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    ")
  end

  def select_index_definitions(database_name)
    postgres.query("
      SELECT
        DISTINCT S.TABLE_NAME, S.COLUMN_NAME, S.SUB_PART, S.NON_UNIQUE, S.INDEX_NAME, S.SEQ_IN_INDEX, S.INDEX_TYPE,
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
        S.TABLE_SCHEMA = '#{postgres.escape(database_name)}'

      UNION ALL

      SELECT
        DISTINCT KCU.TABLE_NAME, KCU.COLUMN_NAME, NULL AS SUB_PART, 0 AS NON_UNIQUE, TC.CONSTRAINT_NAME, 1 AS SEQ_IN_INDEX, '' AS INDEX_TYPE,
        TC.CONSTRAINT_TYPE,
        KCU.REFERENCED_TABLE_NAME, KCU.REFERENCED_COLUMN_NAME
      FROM
        TABLE_CONSTRAINTS TC
      LEFT OUTER JOIN
        KEY_COLUMN_USAGE KCU
      ON
        KCU.CONSTRAINT_SCHEMA = TC.TABLE_SCHEMA
        AND KCU.TABLE_NAME = TC.TABLE_NAME
        AND KCU.CONSTRAINT_NAME = TC.CONSTRAINT_NAME
      WHERE
        TC.TABLE_SCHEMA = '#{postgres.escape(database_name)}'
        AND NOT EXISTS (
          SELECT
            'X'
          FROM
            STATISTICS S
          WHERE
            S.TABLE_SCHEMA = TC.TABLE_SCHEMA
            AND S.TABLE_NAME = TC.TABLE_NAME
            AND TC.CONSTRAINT_NAME = S.INDEX_NAME
        )
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
    option.merge!(auto_increment: table_option['AUTO_INCREMENT']) if table_option['AUTO_INCREMENT']
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
    if column_type.downcase.include?('unsigned')
      options.merge!(unsigned: true)
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
        options = { name: index_name, type: indexes.first['INDEX_TYPE'], unique: type == 'UNIQUE' }
        length = indexes.reject { |v| v['SUB_PART'].nil? }.reduce({}) { |a, e| a[e['COLUMN_NAME']] = e['SUB_PART']; a }
        options.merge!(length: length) unless length.empty?
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
