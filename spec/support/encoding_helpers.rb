module EncodingHelpers
  def force_to_ascii(string)
    return string unless string.respond_to?('force_encoding')

    string.force_encoding('ASCII-8BIT')
    string
  end
end
