class Hash
  def to_o
    JSON.parse to_json, object_class: OpenStruct
  end

  def to_os
    self.each_with_object(OpenStruct.new) do |(key, val), memo|
      memo[key] = val.is_a?(Hash) ? val.to_os : val
    end
  end
end
