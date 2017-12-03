class Convergence::DefaultParameter::PostgresDefaultParameter
  DEFAULT_TABLE_PARAMETERS = {
    default_charset: 'utf8'
  }
  DEFAULT_COLLATE_NAME = {
  }
  DEFAULT_COLUMN_PARAMETERS = {
    null: false
  }
  TEXT_TYPE = [:varchar, :char, :text]
  DEFAULT_COLUMN_TYPE_PARAMETERS = {
  }
  DEFAULT_INDEX_PARAMETERS = {
  }

  def initialize
  end

  def remove_default_parameter(table)
    remove_column_default_parameter(table)
    remove_table_default_parameter(table)
    remove_index_default_parameter(table)
    table
  end

  def append_default_parameter(table)
    append_column_default_parameter(table)
    append_table_default_parameter(table)
    append_index_default_parameter(table)
    table
  end

  private

  def remove_column_default_parameter(table)
    table.columns.each do |_column_name, column|
      type = column.type
      parameters = DEFAULT_COLUMN_PARAMETERS.merge(DEFAULT_COLUMN_TYPE_PARAMETERS[type] || {})
      if TEXT_TYPE.include?(type)
        character_set = table.table_options[:default_charset] || DEFAULT_TABLE_PARAMETERS[:default_charset]
        parameters = parameters.merge(
          character_set: character_set,
          collate: table.table_options[:collate] || DEFAULT_COLLATE_NAME[character_set.downcase])
      end
      parameters.each do |k, v|
        if !column.options[k].nil? && column.options[k].to_s.downcase == v.to_s.downcase
          column.options.delete(k)
        end
      end
    end
  end

  def remove_table_default_parameter(table)
    table.table_options.each do |k, v|
      if !DEFAULT_TABLE_PARAMETERS[k].nil? && DEFAULT_TABLE_PARAMETERS[k].downcase == v.to_s.downcase
        table.table_options.delete(k)
      end
    end
  end

  def remove_index_default_parameter(table)
    table.indexes.each do |_, va|
      va.options.each do |k, v|
        if !DEFAULT_INDEX_PARAMETERS[k].nil? && DEFAULT_INDEX_PARAMETERS[k].downcase == v.to_s.downcase
          va.options.delete(k)
        end
      end
    end
  end

  def append_column_default_parameter(table)
    table.columns.each do |_column_name, column|
      type = column.type
      parameters = DEFAULT_COLUMN_PARAMETERS
        .merge(DEFAULT_COLUMN_TYPE_PARAMETERS[type] || {})
        .merge(column.options)
      if TEXT_TYPE.include?(type)
        character_set = table.table_options[:default_charset] || DEFAULT_TABLE_PARAMETERS[:default_charset]
        parameters = {
          character_set: character_set,
          collate: table.table_options[:collate] || DEFAULT_COLLATE_NAME[character_set.downcase]
        }.merge(parameters)
      end
      column.options = parameters
    end
  end

  def append_table_default_parameter(table)
    table.table_options = DEFAULT_TABLE_PARAMETERS.merge(table.table_options)
    if table.table_options[:collate].nil?
      table.table_options.merge!(collate: DEFAULT_COLLATE_NAME[table.table_options[:default_charset].downcase])
    end
  end

  def append_index_default_parameter(table)
    table.indexes.each do |_column_name, column|
      parameters = DEFAULT_INDEX_PARAMETERS.merge(column.options)
      column.options = parameters
    end
  end
end
