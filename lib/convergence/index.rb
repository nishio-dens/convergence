class Convergence::Index
  attr_accessor :index_name, :index_columns, :options

  def initialize(index_name, index_columns, options)
    @index_name = index_name
    @index_columns = [index_columns].flatten.map(&:to_s)
    @options = { name: @index_name }.merge(options)
    length = @options[:length]
    case length
    when Hash
      @options[:length] = Hash[length.map { |k, v| [k.to_s, v] }]
    when Integer
      @options[:length] = Hash[@index_columns.map { |col| [col, length] }]
    end
  end

  def quoted_columns
    option_strings = Hash[@index_columns.map { |name| [name, ''] }]
    option_strings = add_index_length(option_strings, @index_columns, @options)
    @index_columns.map { |name| quote_column_name(name) + option_strings[name] }
  end

  private

  def quote_column_name(name)
    "`#{name.to_s.gsub('`', '``')}`"
  end

  def add_index_length(option_strings, column_names, options = {})
    if length = options[:length]
      column_names.each { |name| option_strings[name] += "(#{length[name]})" if length.has_key?(name) && !length[name].nil? }
    end
    option_strings
  end
end
