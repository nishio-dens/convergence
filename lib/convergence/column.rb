class Convergence::Column
  attr_accessor :type, :column_name, :options

  COLUMN_TYPE = %i(
    tinyint
    smallint
    mediumint
    int
    bigint
    float
    double
    decimal
    char
    varchar
    tinyblob
    blob
    mediumblob
    longblob
    tinytext
    text
    mediumtext
    longtext
    enum
    set
    date
    time
    datetime
    timestamp
    year
    json
    inet
  )
  FLOATING_POINT_COLUMN_TYPE = %i(
    float
    double
    decimal
  )
  POSTGRES_COLUMN_MAPPINGS = [
    # Postgres Type, Convergence Type
    [:int8,          :int],
    [:int4,          :smallint],
    [:bool,          :boolean],
    [:timestamp,     :datetime]
  ]

  def initialize(type, column_name, options = {})
    @type = type
    @column_name = column_name
    @options = options
  end
end
