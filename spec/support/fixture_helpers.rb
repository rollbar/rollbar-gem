module FixtureHelpers
  def fixture_file(relative_path)
    root = File.expand_path('../../fixtures', __FILE__)
    File.join(root, relative_path)
  end

  def load_payload_fixture(relative_path)
    MultiJson.load(File.read(fixture_file(relative_path)))
  end

  def symbolize_recursive(hash)
    {}.tap do |h|
      hash.each { |key, value| h[key.to_sym] = map_value(value) }
    end
  end

  def map_value(thing)
    case thing
    when Hash
      symbolize_recursive(thing)
    when Array
      thing.map { |v| map_value(v) }
    else
      thing
    end
  end
end
