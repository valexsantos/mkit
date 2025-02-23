class Hash
  def to_o
    JSON.parse to_json, object_class: OpenStruct
  end

  def to_os
    self.each_with_object(OpenStruct.new) do |(key, val), memo|
      memo[key] = val.is_a?(Hash) ? val.to_os : val
    end
  end

  def remove_symbols_from_keys
    self.each_with_object({}) do |(k, v), new_hash|
      new_key = k.to_s
      new_value = if v.is_a?(Hash)
                    v.remove_symbols_from_keys
                  elsif v.is_a?(Array)
                    v.map { |item| item.is_a?(Hash) ? item.remove_symbols_from_keys : item }
                  else
                    v
                  end
      new_hash[new_key] = new_value
    end
  end
end
