require 'convergence/default_parameter'

class Convergence::DefaultParameter::PostgresDefaultParameter
  DEFAULT_COLUMN_PARAMETERS = {
    null: false
  }
  DEFAULT_INDEX_PARAMETERS = { type: 'btree', unique: false }

  def initialize
  end

  def remove_default_parameter(table)
    remove_column_default_parameter(table)
    remove_index_default_parameter(table)
    table
  end

  def append_default_parameter(table)
    append_column_default_parameter(table)
    append_index_default_parameter(table)
    table
  end

  private

  def remove_column_default_parameter(table)
    table.columns.each do |_column_name, column|
      DEFAULT_COLUMN_PARAMETERS.each do |k, v|
        if !column.options[k].nil? && column.options[k].to_s.downcase == v.to_s.downcase
          column.options.delete(k)
        end
      end
    end
  end

  def remove_index_default_parameter(table)
    table.indexes.each do |_, va|
      va.options.each do |k, v|
        if !DEFAULT_INDEX_PARAMETERS[k].nil? && DEFAULT_INDEX_PARAMETERS[k].to_s.downcase == v.to_s.downcase
          va.options.delete(k)
        end
      end
    end
  end

  def append_column_default_parameter(table)
    table.columns.each do |_column_name, column|
      column.options = DEFAULT_COLUMN_PARAMETERS.merge(column.options)
    end
  end

  def append_index_default_parameter(table)
    table.indexes.each do |_column_name, column|
      column.options = DEFAULT_INDEX_PARAMETERS.merge(column.options)
    end
  end
end
