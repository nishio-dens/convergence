require 'diff/lcs'

class Convergence::Diff
  def diff(from_database, to_database)
    delta = {}
    from_database = {} if from_database.nil?
    delta[:add_table] = scan_add_table(from_database, to_database)
    delta[:remove_table] = scan_remove_table(from_database, to_database)
    change_table = scan_change_table(from_database, to_database)
    delta[:change_table] = change_table[:change]
    delta[:remove_table].merge!(change_table[:remove])
    delta[:add_table].merge!(change_table[:add])
    delta
  end

  def diff_table(from_table, to_table)
    from = from_table.dup
    to = to_table.dup
    delta = {}
    delta[:remove_column] = scan_remove_column(from, to)
    return delta if removed_all_columns?(from, delta)
    delta[:add_column] = scan_add_column(from, to)
    delta[:change_column] = scan_change_column(from, to)
    scan_change_order_column(from, to, delta)
    delta[:remove_index] = scan_change_index(to, from)
    delta[:add_index] = scan_change_index(from, to)
    delta[:remove_foreign_key] = scan_change_foreign_key(to, from)
    delta[:add_foreign_key] = scan_change_foreign_key(from, to)
    delta[:change_table_option] = scan_change_table_option(from, to)
    delta
  end

  private

  def scan_add_table(from, to)
    to.reject { |table_name, _| from.map { |k, _| k }.include?(table_name) }
  end

  def scan_remove_table(from, to)
    from.reject { |table_name, _| to.map { |k, _| k }.include?(table_name) }
  end

  def scan_change_table(from, to)
    delta = { change: {}, remove: {}, add: {}}
    target_tables = from.map { |name, _| name } & to.map { |name, _| name }
    target_tables.each do |target_table|
      from_table = from.find { |name, _| name == target_table }[1]
      to_table = to.find { |name, _| name == target_table }[1]
      diff = diff_table(from_table, to_table)
      unless diff.values.all?(&:empty?)
        if removed_all_columns?(from_table, diff)
          delta[:remove][target_table] = from_table
          delta[:add][target_table] = to_table
        else
          delta[:change][target_table] = diff
        end
      end
    end
    delta
  end

  def scan_add_column(from, to)
    to.columns.reject { |column_name, _| from.columns.keys.include?(column_name) }
  end

  def scan_remove_column(from, to)
    from.columns.reject { |column_name, _| to.columns.keys.include?(column_name) }
  end

  def scan_change_column(from, to)
    change_columns = from
      .columns
      .map do |column_name, from_column|
        to_column = to.columns[column_name]
        if to_column
          to_column_option_with_type = (from_column.options.map { |k, _v| { k => nil } }.reduce { |a, e| a.merge(e) } || {})
            .merge(to_column.options)
            .merge(type: to_column.type)
            .map { |k, v| [k, v.to_s.downcase] }
            .to_a
          from_column_option_with_type = from_column
            .options
            .merge(type: from_column.type)
            .map { |k, v| [k, v.to_s.downcase] }
            .to_a
          { column_name => Hash[(to_column_option_with_type - from_column_option_with_type)] }
        end
      end
    change_columns
      .compact
      .reduce({}) { |a, e| a.merge(e) }
      .reject { |_k, v| v.empty? }
  end

  def scan_change_order_column(from, to, delta)
    from_columns = from.columns.keys
    to_columns = to.columns.keys
    order_changed_columns = Diff::LCS.diff(from_columns, to_columns)
      .flatten
      .select(&:adding?)
      .map(&:element)
    order_changed_columns.each do |column|
      before_column_index = to_columns.index { |v| v == column } - 1
      before_column = if before_column_index < 0
                        nil
                      else
                        to_columns[before_column_index]
                      end
      if delta[:add_column][column]
        delta[:add_column][column].options.merge!(after: before_column)
      else
        delta[:change_column][column] = {} if delta[:change_column][column].nil?
        delta[:change_column][column].merge!(after: before_column)
      end
    end
  end

  def scan_change_index(from, to)
    delta = {}
    to.indexes.each do |name, index|
      candidate_index = from.indexes.find { |from_name, _| from_name == name }
      if candidate_index.nil? || candidate_index[1].options != index.options
        delta[name] = index
      end
    end
    delta
  end

  def scan_change_foreign_key(from, to)
    delta = {}
    to.foreign_keys.each do |name, fk|
      candidate_foreign_keys = from.foreign_keys.find { |from_name, _| from_name == name }
      target_fk = candidate_foreign_keys[1] rescue nil
      if candidate_foreign_keys.nil?
        delta[name] = fk
      elsif !target_fk.nil?
        if target_fk.from_columns != fk.from_columns ||
          target_fk.key_name != fk.key_name ||
          target_fk.options != fk.options ||
          target_fk.to_columns != fk.to_columns ||
          target_fk.to_table != fk.to_table
          delta[name] = fk
        end
      end
    end
    delta
  end

  def scan_change_table_option(from, to)
    change_options = (from.table_options.map { |k, _v| { k => nil } }.reduce { |a, e| a.merge(e) } || {})
      .merge(to.table_options)
      .reject do |k, v|
        !from.table_options[k].nil? && from.table_options[k].to_s.downcase == v.to_s.downcase
      end
    Hash[change_options]
  end

  def removed_all_columns?(from_table, diff)
    from_table.columns.each_key.all? { |name| diff[:remove_column].each_key.include?(name) }
  end
end
