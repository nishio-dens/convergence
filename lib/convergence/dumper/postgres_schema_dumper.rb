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
        INFORMATION_SCHEMA.TABLES TABLES
      WHERE
        TABLE_SCHEMA = '#{postgres.escape(schema)}'
      ORDER BY
        TABLE_NAME
    ")
  end

  def select_column_definitions(schema)
    postgres.exec("
      SELECT * FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = '#{postgres.escape(schema)}'
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    ")
  end

  def select_index_definitions(schema)
    # FIXME: support all indexes
    #    subpart, foreign_key, unique/non_unique etc...
    foreign_key_query = <<-EOS
      SELECT
        DISTINCT TC.TABLE_NAME,
        KCU.COLUMN_NAME,
        NULL AS SUB_PART,
        FALSE AS NON_UNIQUE,
        TC.CONSTRAINT_NAME AS INDEX_NAME,
        KCU.ORDINAL_POSITION AS SEQ_IN_INDEX,
        TC.CONSTRAINT_TYPE AS INDEX_TYPE,
        TC.CONSTRAINT_TYPE,
        '' AS REFERENCED_TABLE_NAME,
        '' AS REFERENCED_COLUMN_NAME
      FROM
        INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC
      LEFT OUTER JOIN
        INFORMATION_SCHEMA.KEY_COLUMN_USAGE KCU
      ON
        KCU.CONSTRAINT_SCHEMA = '#{postgres.escape(schema)}'
        AND TC.TABLE_NAME = KCU.TABLE_NAME
        AND TC.CONSTRAINT_NAME = KCU.CONSTRAINT_NAME
      WHERE
        TC.TABLE_SCHEMA = 'public'
        AND TC.CONSTRAINT_TYPE != 'CHECK'
    EOS
    index_query = <<-EOS
    SELECT
      IDXS.TABLENAME AS TABLE_NAME,
      C.COLUMN_NAME,
      NULL AS SUB_PART,
      (NOT IDX.INDISUNIQUE) AS NON_UNIQUE,
      IDXS.INDEXNAME AS INDEX_NAME,
      IDX.SEQ_IN_INDEX,
      'XXX_FIXME_BTREE' AS INDEX_TYPE,
      'INDEX' AS CONSTRAINT_TYPE,
      NULL AS REFERENCED_TABLE_NAME,
      NULL AS REFERENCED_COLUMN_NAME
    FROM
      PG_INDEXES AS IDXS
    INNER JOIN
      INFORMATION_SCHEMA.COLUMNS C
    ON
      C.TABLE_NAME = IDXS.TABLENAME
    INNER JOIN
      (
        SELECT
          INDEXRELID,
          INDISUNIQUE,
          UNNEST(INDKEY) AS INDKEY,
          GENERATE_SUBSCRIPTS(IDX.INDKEY, 1) AS SEQ_IN_INDEX
        FROM
          PG_INDEX IDX
       ) IDX
    ON
      IDXS.INDEXNAME::regclass = IDX.INDEXRELID
    WHERE
      IDXS.SCHEMANAME = 'public'
      AND C.TABLE_SCHEMA = 'public'
      AND C.ORDINAL_POSITION = IDX.INDKEY
      AND IDXS.INDEXNAME NOT LIKE '%pg_toast_%'
    EOS

    postgres.exec("#{foreign_key_query} UNION ALL #{index_query}")
  end

  def parse_table_options(table, table_option)
    option = {}
    option.merge!(collate: table_option['table_collation']) if table_option['table_collation']
    option.merge!(comment: table_option['table_comment']) if table_option['table_comment']
    option.merge!(auto_increment: table_option['auto_increment']) if table_option['auto_increment']
    table.table_options = option
  end

  def parse_columns(table, columns)
    columns.each do |column|
      data_type, column_name, options = parse_column(column)
      table.send(data_type, column_name, options)
    end
  end

  def parse_column(column)
    data_type, is_array = to_convergence_type(column['udt_name'])
    column_name = column['column_name']
    options = { null: column['is_nullable'] == 'YES' ? true : false }
    unless column['column_default'].nil?
      if column['column_default'] == 'NULL::character varying'
        # Nothing
      elsif column['column_default'] =~ /^nextval\('(.*)_seq'::(.*)\)/
        extra_column, _klass = $1, $2
        options.merge!(extra: :auto_increment)
      else
        default_value = column['column_default']
          .gsub(/::character varying$/, "")
          .gsub(/^''$/, "")
        options.merge!(default: default_value)
      end
    end
    options.merge!(array: true) if is_array
    options.merge!(character_set: column['character_set_name']) unless column['character_set_name'].nil?
    column_type = column['column_type']
    # FIXME: Support precision
    # FIXME: Support Column Comment
    [data_type, column_name, options]
  end

  def to_convergence_type(postgres_type)
    is_array = postgres_type.start_with?("_")
    type = postgres_type.gsub(/^_/, "")
    type_mapping = Convergence::Column::POSTGRES_COLUMN_MAPPINGS.find { |ptype, _convergence_type| type.to_sym == ptype }

    if type_mapping.nil?
      [type, is_array]
    else
      [type_mapping[1], is_array]
    end
  end

  def parse_indexes(table, table_indexes)
    return if table_indexes.nil?
    table_indexes.group_by { |r| r['index_name'] }.each do |index_name, indexes|
      type = indexes.first['constraint_type']
      columns = indexes.map { |v| v['column_name'] }
      case type
      when 'PRIMARY KEY'
        indexes.map { |r| r['column_name'] }.each do |column|
          options = { primary_key: true }.merge(table.columns[column].options)
          table.columns[column].options = options
        end
      when 'FOREIGN KEY'
        to_table = indexes.first['referenced_table_name']
        to_columns = indexes.map { |v| v['referenced_column_name'] }
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
