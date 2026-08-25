class Convergence::Dumper
  # Convergence's DSL type names follow MySQL terminology; map them to the
  # closest ActiveRecord migration column type.
  RAILS_TYPE_MAPPING = {
    tinyint: :integer,
    smallint: :integer,
    mediumint: :integer,
    int: :integer,
    bigint: :bigint,
    float: :float,
    double: :float,
    decimal: :decimal,
    char: :string,
    varchar: :string,
    tinyblob: :binary,
    blob: :binary,
    mediumblob: :binary,
    longblob: :binary,
    tinytext: :text,
    text: :text,
    mediumtext: :text,
    longtext: :text,
    date: :date,
    time: :time,
    datetime: :datetime,
    timestamp: :datetime,
    year: :integer,
    json: :json,
    # ActiveRecord has no native enum/set column type; fall back to string.
    enum: :string,
    set: :string
  }.freeze
  # Options that only make sense for convergence's own SQL generators, with no
  # equivalent in an ActiveRecord migration's create_table DSL.
  RAILS_UNSUPPORTED_COLUMN_OPTIONS = %i[character_set collate extra after values].freeze

  def dump_dsl(tables)
    tables.map do |_, table|
      dump_table_dsl(table)
    end.join("\n\n")
  end

  def dump_table_dsl(table)
    table_argument = [table.table_name.to_sym.inspect]
    table_argument << table.table_options.map { |k, v| key_value_text(k, v) }
    dsl = "create_table #{table_argument.flatten.join(', ')} do |t|\n"
    dsl += "  #{table.columns.map { |_, column| dump_column(column) }.join("\n  ")}"
    dsl += "\n" if !table.indexes.empty? || !table.foreign_keys.empty?
    dsl += "\n"
    unless table.indexes.empty?
      dsl += "  #{table.indexes.map { |_, index| dump_index(index) }.join("\n  ")}"
      dsl += "\n"
    end
    unless table.foreign_keys.empty?
      dsl += "  #{table.foreign_keys.map { |_, key| dump_foreign_key(key) }.join("\n  ")}"
      dsl += "\n"
    end
    dsl += 'end'
    dsl
  end

  def dump_rails_migration(tables, class_name, rails_version: '7.0')
    dsl = "class #{class_name} < ActiveRecord::Migration[#{rails_version}]\n"
    dsl += "  def change\n"
    dsl += tables.map { |_, table| dump_table_rails_migration(table) }.join("\n\n")
    dsl += "\n  end\n"
    dsl += 'end'
    dsl
  end

  def dump_table_rails_migration(table)
    table_argument = [table.table_name.to_sym.inspect]
    dsl = "    create_table #{table_argument.join(', ')} do |t|\n"
    body_lines = rails_column_lines(table.columns)
    body_lines += table.indexes.map { |_, index| dump_rails_index(index) }
    body_lines += table.foreign_keys.map { |_, key| dump_rails_foreign_key(key) }
    dsl += body_lines.map { |line| "      #{line}" }.join("\n")
    dsl += "\n    end"
    dsl
  end

  private

  # ActiveRecord's create_table implicitly adds an auto-incrementing `id`
  # primary key, so an explicit column matching that shape is redundant.
  def default_primary_key_column?(column_name, column)
    column_name == 'id' &&
      [:int, :bigint].include?(column.type) &&
      column.options[:primary_key] &&
      column.options[:extra].to_s.upcase.include?('AUTO_INCREMENT')
  end

  def rails_timestamp_column?(column)
    column.type == :datetime && Convergence::Dumper::RAILS_UNSUPPORTED_COLUMN_OPTIONS.none? { |k| column.options.key?(k) }
  end

  def rails_column_lines(columns)
    columns = columns.reject { |name, column| default_primary_key_column?(name, column) }
    if %w[created_at updated_at].all? { |name| columns.key?(name) && rails_timestamp_column?(columns[name]) } &&
       columns['created_at'].options[:null] == columns['updated_at'].options[:null]
      remaining = columns.reject { |name, _| %w[created_at updated_at].include?(name) }
      lines = remaining.map { |_, column| dump_rails_column(column) }
      lines << (columns['created_at'].options[:null] ? 't.timestamps' : 't.timestamps null: false')
      lines
    else
      columns.map { |_, column| dump_rails_column(column) }
    end
  end

  def dump_rails_column(column)
    argument = [column.column_name.to_sym.inspect]
    options = column.options.reject { |k, _v| RAILS_UNSUPPORTED_COLUMN_OPTIONS.include?(k) }
    if column.type == :tinyint && column.options[:limit].to_s == '1'
      column_type = :boolean
      options = options.reject { |k, _v| k == :limit }
      options = options.merge(default: false) if options[:default].to_s == '0'
      options = options.merge(default: true) if options[:default].to_s == '1'
    else
      column_type = RAILS_TYPE_MAPPING[column.type] || column.type
    end
    argument << options.map { |k, v| key_value_text(k, v) }
    "t.#{column_type} #{argument.flatten.join(', ')}"
  end

  def dump_rails_index(index)
    argument = [single_or_multiple_symbol(index.index_columns)]
    options = index.options.select { |k, _v| %i[name unique].include?(k) }
    argument << options.map { |k, v| key_value_text(k, v) }
    "t.index #{argument.flatten.join(', ')}"
  end

  def dump_rails_foreign_key(foreign_key)
    argument = [foreign_key.to_table.to_sym.inspect]
    argument << "column: #{single_or_multiple_symbol(foreign_key.from_columns)}"
    argument << "primary_key: #{single_or_multiple_symbol(foreign_key.to_columns)}" unless foreign_key.to_columns == ['id']
    argument << key_value_text('name', foreign_key.key_name)
    "t.foreign_key #{argument.join(', ')}"
  end

  def dump_column(column)
    argument = [column.column_name.to_sym.inspect]
    case [column.type, column.options[:limit]]
    when [:tinyint, '1']
      column_type = "boolean"
      options = column.options.dup
      options.delete(:limit)
      options = options.merge(default: false) if options[:default] == "0"
      options = options.merge(default: true) if options[:default] == "1"
      argument << options.map { |k, v| key_value_text(k, v) }
    else
      column_type = column.type
      argument << column.options.map { |k, v| key_value_text(k, v) }
    end

    "t.#{column_type} #{argument.flatten.join(', ')}"
  end

  def dump_index(index)
    columns = single_or_multiple_symbol(index.index_columns)
    argument = [columns]
    argument << index.options.map { |k, v| key_value_text(k, v) }
    "t.index #{argument.flatten.join(', ')}"
  end

  def dump_foreign_key(foreign_key)
    columns = single_or_multiple_symbol(foreign_key.from_columns)
    argument = [columns]
    argument << [key_value_symbol('reference', foreign_key.to_table)]
    argument << ["reference_column: #{single_or_multiple_symbol(foreign_key.to_columns)}"]
    argument << foreign_key.options.map { |k, v| key_value_text(k, v) }
    "t.foreign_key #{argument.flatten.join(', ')}"
  end

  def single_or_multiple_symbol(values)
    values_array = [values].flatten
    if values_array.size == 1
      values_array.first.to_sym.inspect
    else
      values.map(&:to_sym).inspect
    end
  end

  def key_value_text(k, v)
    value = if v.to_s == 'true' || v.to_s == 'false' || v.to_s =~ /^\d+$/
              v
            elsif v.is_a?(Proc)
              %(-> { #{v.call.inspect} })
            else
              %(#{v.inspect})
            end
    "#{k}: #{value}"
  end

  def key_value_symbol(k, v)
    "#{k}: #{v.to_sym.inspect}"
  end
end
