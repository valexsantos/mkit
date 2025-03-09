# Load custom exceptions
require 'mkit/exceptions'

module CustomExceptions
  def raise_bad_configuration(message)
    raise MKIt::InvalidConfigurationException, "MKIt :: Invalid Configuration :: #{message}"
  end
end

Object.include(CustomExceptions)
