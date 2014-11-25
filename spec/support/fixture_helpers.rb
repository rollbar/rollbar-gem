module FixtureHelpers
  def fixture_file(relative_path)
    root = File.expand_path('../../fixtures', __FILE__)
    File.join(root, relative_path)
  end
end
