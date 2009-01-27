class Hash
  def deep_symbolize_keys
    self.inject({}) do |options, (key, value)|
      value = value.deep_symbolize_keys if value.is_a? Hash
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end

  def deep_symbolize_keys!
    self.replace(self.deep_symbolize_keys)
  end
end