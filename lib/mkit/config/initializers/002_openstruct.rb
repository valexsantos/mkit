class OpenStruct
  def to_hash
    self.each_pair.with_object({}) do |(key, value), hash|
      hash[key] = value.is_a?(OpenStruct) ? value.to_hash : value
    end
  end
end
