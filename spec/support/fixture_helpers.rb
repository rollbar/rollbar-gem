module FixtureHelpers
  def fixture_file(relative_path)
    root = File.expand_path('../../fixtures', __FILE__)
    File.join(root, relative_path)
  end

  def load_payload_fixture(relative_path)
    MultiJson.load(File.read(fixture_file(relative_path)))
  end
end
