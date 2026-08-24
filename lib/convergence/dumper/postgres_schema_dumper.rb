require 'convergence/dumper'
require 'convergence/table'

class Convergence::Dumper::PostgresSchemaDumper
  # Convergence's DSL type names follow MySQL terminology. Map PostgreSQL's
  # internal type name (udt_name) back to the closest DSL type.
  TYPE_MAPPING = {
    'int2' => :smallint,
    'int4' => :int,
    'int8' => :bigint,
    'varchar' => :varchar,
    'bpchar' => :char,
    'text' => :text,
    'bytea' => :blob,
    'timestamp' => :datetime,
    'timestamptz' => :datetime,
    'date' => :date,
    'time' => :time,
    'numeric' => :decimal,
    'float4' => :float,
    'float8' => :double,
    'json' => :json,
    'jsonb' => :json
  }.freeze
  DEFAULT_VALUE_PATTERN = /\A'(?<value>(?:[^']|'')*)'(?:::[\w. ]+)?\z/.freeze

  def initialize(connector)
    @connector = connector
    @target_database = connector.config.database
    @tables = {}
  end

  def dump
    table_definitions = select_table_definitions
    column_definitions = select_column_definitions.group_by { |r| r['table_name'] }
    index_definitions = select_index_definitions.group_by { |r| r['table_name'] }
    foreign_key_definitions = select_foreign_key_definitions.group_by { |r| r['table_name'] }
    table_definitions.map { |r| r['table_name'] }.each do |table_name|
      table = Convergence::Table.new(table_name)
      parse_table_options(table, table_definitions.find { |r| r['table_name'] == table_name })
      parse_columns(table, column_definitions[table_name])
      parse_indexes(table, index_definitions[table_name])
      parse_foreign_keys(table, foreign_key_definitions[table_name])
      @tables[table_name] = table
    end
    @tables
  end

  private

  def pg
    @connector.schema_client
  end

  def select_table_definitions
    pg.query("
      SELECT
        c.relname AS table_name,
        obj_description(c.oid) AS table_comment
      FROM pg_class c
      INNER JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relkind = 'r' AND n.nspname = 'public'
      ORDER BY c.relname
    ").to_a
  end

  def select_column_definitions
    pg.query("
      SELECT
        c.table_name, c.column_name, c.ordinal_position, c.udt_name, c.is_nullable, c.column_default,
        c.character_maximum_length, c.numeric_precision, c.numeric_scale, c.is_identity,
        col_description(pgc.oid, c.ordinal_position) AS column_comment
      FROM information_schema.columns c
      INNER JOIN pg_class pgc ON pgc.relname = c.table_name
      INNER JOIN pg_namespace pgn ON pgn.oid = pgc.relnamespace AND pgn.nspname = c.table_schema
      WHERE c.table_schema = 'public'
      ORDER BY c.table_name, c.ordinal_position
    ").to_a
  end

  def select_index_definitions
    pg.query("
      SELECT
        t.relname AS table_name,
        i.relname AS index_name,
        a.attname AS column_name,
        ix.indisunique AS is_unique,
        ix.indisprimary AS is_primary,
        array_position(ix.indkey, a.attnum) AS seq_in_index
      FROM pg_index ix
      INNER JOIN pg_class t ON t.oid = ix.indrelid
      INNER JOIN pg_class i ON i.oid = ix.indexrelid
      INNER JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
      INNER JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = 'public'
      ORDER BY t.relname, i.relname, seq_in_index
    ").to_a
  end

  def select_foreign_key_definitions
    pg.query("
      SELECT
        tc.table_name,
        tc.constraint_name,
        kcu.column_name,
        ccu.table_name AS referenced_table_name,
        ccu.column_name AS referenced_column_name
      FROM information_schema.table_constraints tc
      INNER JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
      INNER JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
    ").to_a
  end

  def parse_table_options(table, table_option)
    option = {}
    option.merge!(comment: table_option['table_comment']) unless table_option['table_comment'].nil?
    table.table_options = option
  end

  def parse_columns(table, columns)
    return if columns.nil?
    columns.each do |column|
      data_type, column_name, options = parse_column(column)
      table.send(data_type, column_name, options)
    end
  end

  def parse_column(column)
    data_type = TYPE_MAPPING[column['udt_name']] || column['udt_name'].to_sym
    column_name = column['column_name']
    options = { null: column['is_nullable'] == 'YES' }
    if column['is_identity'] == 'YES'
      options.merge!(extra: 'auto_increment')
    elsif !column['column_default'].nil?
      options.merge!(default: column_default_expression(data_type, column['column_default']))
    end
    case data_type
    when :decimal
      options.merge!(precision: column['numeric_precision'], scale: column['numeric_scale'])
    when :varchar, :char
      options.merge!(limit: column['character_maximum_length']) unless column['character_maximum_length'].nil?
    end
    options.merge!(comment: column['column_comment']) unless column['column_comment'].nil?
    [data_type, column_name, options]
  end

  def column_default_expression(data_type, value)
    return -> { 'CURRENT_TIMESTAMP' } if [:datetime].include?(data_type) && value.start_with?('CURRENT_TIMESTAMP')
    match = DEFAULT_VALUE_PATTERN.match(value)
    return match[:value].gsub("''", "'") if match
    value
  end

  def parse_indexes(table, table_indexes)
    return if table_indexes.nil?
    table_indexes.group_by { |r| r['index_name'] }.each do |index_name, indexes|
      columns = indexes.sort_by { |r| r['seq_in_index'].to_i }.map { |v| v['column_name'] }
      if indexes.first['is_primary'] == 't'
        columns.each do |column|
          options = { primary_key: true }.merge(table.columns[column].options)
          table.columns[column].options = options
        end
      else
        options = { name: index_name, unique: indexes.first['is_unique'] == 't' }
        table.index(columns, options)
      end
    end
  end

  def parse_foreign_keys(table, foreign_keys)
    return if foreign_keys.nil?
    foreign_keys.group_by { |r| r['constraint_name'] }.each do |constraint_name, rows|
      columns = rows.map { |r| r['column_name'] }
      to_table = rows.first['referenced_table_name']
      to_columns = rows.map { |r| r['referenced_column_name'] }
      options = {
        reference: to_table,
        reference_column: to_columns,
        name: constraint_name
      }
      table.foreign_key(columns, options)
    end
  end
end
