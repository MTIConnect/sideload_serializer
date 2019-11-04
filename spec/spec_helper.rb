$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_support/core_ext/object/deep_dup'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_model_serializers'
require 'sideload_serializer'

Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each { |f| require f }
