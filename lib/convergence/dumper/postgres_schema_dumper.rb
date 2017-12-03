# FIXME: fix something for postgres
class Convergence::Dumper::PostgresSchemaDumper
  def initialize(connector)
    @connector = connector
    @tables = {}
    @schema = 'public' # FIXME: support postgres schema
  end

  def dump
    table_definitions = select_table_definitions(@schema)
    column_definitions = select_column_definitions(@schema).group_by { |r| r['table_name'] }
    index_definitions = select_index_definitions(@schema).group_by { |r| r['table_name'] }
    table_definitions.map { |r| r['table_name'] }.each do |table_name|
      table = Convergence::Table.new(table_name)
      parse_table_options(table, table_definitions.find { |r| r['table_name'] == table_name })
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

  def select_table_definitions(schema)
    postgres.exec("
      SELECT
        *
      FROM
        information_schema.TABLES TABLES
      WHERE
        TABLE_SCHEMA = '#{postgres.escape(schema)}'
      ORDER BY
        TABLE_NAME
    ")
  end

  def select_column_definitions(schema)
    postgres.exec("
      SELECT * FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = '#{postgres.escape(schema)}'
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    ")
  end

  def select_index_definitions(schema)
    # FIXME: support all indexes
    #    subpart, foreign_key, unique/non_unique etc...
    postgres.exec("
      SELECT
        DISTINCT TC.TABLE_NAME, KCU.COLUMN_NAME, NULL AS SUB_PART, NULL AS NON_UNIQUE, TC.CONSTRAINT_NAME AS INDEX_NAME,
        KCU.ORDINAL_POSITION AS SEQ_IN_INDEX, TC.CONSTRAINT_TYPE AS INDEX_TYPE,
        TC.CONSTRAINT_TYPE,
        '' AS REFERENCED_TABLE_NAME, '' AS REFERENCED_COLUMN_NAME
      FROM
        information_schema.TABLE_CONSTRAINTS TC
      LEFT OUTER JOIN
        information_schema.KEY_COLUMN_USAGE KCU
      ON
        KCU.CONSTRAINT_SCHEMA = '#{postgres.escape(schema)}'
        AND TC.TABLE_NAME = KCU.TABLE_NAME
        AND TC.CONSTRAINT_NAME = KCU.CONSTRAINT_NAME
      WHERE
        TC.TABLE_SCHEMA = 'public'
    ")
  end

  def parse_table_options(table, table_option)
    option = {}
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
    data_type = to_convergence_type(column['udt_name'])
    column_name = column['column_name']
    options = { null: column['is_nullable'] == 'YES' ? true : false }
    options.merge!(default: column['column_default']) unless column['column_default'].nil?
    options.merge!(character_set: column['character_set_name']) unless column['character_set_name'].nil?
    options.merge!(collate: column['column_name']) unless column['column_name'].nil?
    column_type = column['column_type']
    # FIXME: Support precision
    # FIXME: Support Column Comment
    [data_type, column_name, options]
  end

  def to_convergence_type(postgres_type)
    type_mapping = Convergence::Column::POSTGRES_COLUMN_MAPPINGS.find { |ptype, _convergence_type| postgres_type.to_sym == ptype }
    type_mapping.nil? ? postgres_type : type_mapping[1]
  end

  def parse_indexes(table, table_indexes)
    return if table_indexes.nil?

    # FIXME: for postgres
    table_indexes.group_by { |r| r['index_name'] }.each do |index_name, indexes|
      type = indexes.first['constraint_type']
      columns = indexes.map { |v| v['column_name'] }
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
