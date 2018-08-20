require 'erb'
require 'yaml'

class Convergence::Config
  ATTRIBUTES = %i[adapter database host port username password].freeze

  attr_accessor(*ATTRIBUTES)

  def initialize(attributes)
    attributes.each do |k, v|
      next if v.nil?
      next if !ATTRIBUTES.include?(k.to_sym) && !ATTRIBUTES.include?(k.to_s)
      instance_variable_set("@#{k}", v)
    end
  end

  def self.load(yaml_path)
    setting = YAML.load(ERB.new(File.read(yaml_path)).result)
    new(setting)
  end
end
