class Convergence::DefaultParameter::MysqlDefaultParameter
  DEFAULT_TABLE_PARAMETERS = {
    engine: 'InnoDB',
    row_format: 'Compact',
    default_charset: 'utf8'
  }
  DEFAULT_COLLATE_NAME = {
    'big5' => 'big5_chinese_ci',
    'dec8' => 'dec8_swedish_ci',
    'cp850' => 'cp850_general_ci',
    'hp8' => ' hp8_english_ci',
    'koi8r' => ' koi8r_general_ci',
    'latin1' => 'latin1_swedish_ci',
    'latin2' => 'latin2_general_ci',
    'swe7' => 'swe7_swedish_ci',
    'ascii' => 'ascii_general_ci',
    'ujis' => 'ujis_japanese_ci',
    'sjis' => 'sjis_japanese_ci',
    'hebrew' => 'hebrew_general_ci',
    'tis620' => 'tis620_thai_ci',
    'euckr' => 'euckr_korean_ci',
    'koi8u' => 'koi8u_general_ci',
    'gb2312' => 'gb2312_chinese_ci',
    'greek' => ' greek_general_ci',
    'cp1250' => 'cp1250_general_ci',
    'gbk' => 'gbk_chinese_ci',
    'latin5' => 'latin5_turkish_ci',
    'armscii8' => 'armscii8_general_ci',
    'utf8' => 'utf8_general_ci',
    'ucs2' => 'ucs2_general_ci',
    'cp866' => 'cp866_general_ci',
    'keybcs2' => 'keybcs2_general_ci',
    'macce' => 'macce_general_ci',
    'macroman' => 'macroman_general_ci',
    'cp852' => 'cp852_general_ci',
    'latin7' => 'latin7_general_ci',
    'utf8mb4' => 'utf8mb4_general_ci',
    'cp1251' => 'cp1251_general_ci',
    'utf16' => 'utf16_general_ci',
    'utf16le' => 'utf16le_general_ci',
    'cp1256' => 'cp1256_general_ci',
    'cp1257' => 'cp1257_general_ci',
    'utf32' =>  'utf32_general_ci',
    'binary' => 'binary',
    'geostd8' => 'eostd8_general_ci',
    'cp932' => 'cp932_japanese_ci',
    'eucjpms' => 'ucjpms_japanese_ci'
  }
  DEFAULT_COLUMN_PARAMETERS = {
    null: false
  }
  TEXT_TYPE = [:varchar, :char, :tiny_text, :text, :mediumtext, :longtext]
  DEFAULT_COLUMN_TYPE_PARAMETERS = {
    tinyint: {
      limit: 3
    },
    smallint: {
      limit: 5
    },
    mediumint: {
      limit: 8
    },
    int: {
      limit: 11
    },
    bigint: {
      limit: 19
    },
    varchar: {
      limit: 255
    }
  }
  DEFAULT_INDEX_PARAMETERS = { type: 'BTREE', unique: false }

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
