class MockApp
  def call(_env)
    return [200, {}, ['Success']]
  end
end
