class Convergence::Dumper
  def dump_dsl(tables)
    tables.map do |_, table|
      dump_table_dsl(table)
    end.join("\n\n")
  end

  def dump_table_dsl(table)
    table_argument = [":#{table.table_name}"]
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

  private

  def dump_column(column)
    argument = [%(:#{column.column_name})]
    argument << column.options.map { |k, v| key_value_text(k, v) }
    "t.#{column.type} #{argument.flatten.join(', ')}"
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
      ":#{values_array.first}"
    else
      %(#{values.map(&:to_sym)})
    end
  end

  def key_value_text(k, v)
    value = if v.to_s == 'true' || v.to_s == 'false' || v =~ /^\d+$/
              v
            else
              %(#{v.inspect})
            end
    "#{k}: #{value}"
  end

  def key_value_symbol(k, v)
    "#{k}: :#{v}"
  end
end
