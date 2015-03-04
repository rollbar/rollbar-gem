require 'genspec'

RSpec.configure do |config|
  # Set the example group to spec/rails/generators
  config.include GenSpec::GeneratorExampleGroup, :example_group => { :file_path => /spec\/rails\/generators\/rollbar\// }

  # Kick off the action wrappers.
  #
  # This has to be deferred until the specs run so that the
  # user has a chance to add custom action modules to the
  # list.
  config.before(:each) do
    if self.class.include?(GenSpec::GeneratorExampleGroup) # if this is a generator spec
      GenSpec::Matchers.add_shorthand_methods(self.class)
    end
  end
end
