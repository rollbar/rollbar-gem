# Plugins

The plugins architecture offers an easy way to load the wrappers for libaries or frameworks we want to send Rollbar reports from. The different plugins we've written can be found in https://github.com/rollbar/rollbar-gem/tree/master/lib/rollbar/plugins. In this document we'll explain the interface that a plugin offers.

In case you'd like to open a PR in this gem in order to add a plugins for a library or framework we still don't support, you should write a file wit the name of the framework you want to wrap in `lib/rollbar/plugins`. Here an example of a plugin:

```ruby
# lib/rollbar/plugins/my_framework.rb

Rollbar.plugins.define('my-framework') do
  require_dependency 'my_framework'
  dependency { defined?(MyFramework::ErrorHandlers) }

  execute! do
    # This block is executed before Rollbar.configure is called
  end

  execute do
    MyWramework::ErrorHandlers.add do |e| do
      Rollbar.error(e)
    end
  end
end
```

In the example from above you can guess we've defined a plugin called `my-framework` using the statement `Rollbar.plugins.define('my-framework')`. All the Rollbar plugins are defined under `Rollbar.plugins`, an instance of `Rollbar::Plugins`, that is a kind of plugins manager.

## Plugin DSL

The DSL used in the plugins architecture is quite easy:

- `dependency` recieves a block that will be executed in order to evaluate if the `execute` blocks should be executed or not. You can define any number of `dependency` blocks. If any of those return a not truthy value, the `execute` blocks will be avoided and your plugin will not have any impact on the gem behavior.

- `require_dependency` receives a string. It just calls `require` with the passed string, if the `require` call was successfuly, the plugin loading continues and it'll be stoped if the `require` wasn't successfuly. This is useful in those cases you want to ensure the library or framework gem you want to wrap really exists in the project.

- `execute` also receives a block. You can define any number of `execute` blocks that will be executed in order if all the dependencies, defined by the `dependency` blocks, are satisfied. In the block passed to `execute` you should add the error handler for the framework you are wrapping, inject a module to an existing one, monkey patch a class, or whatever you need in order to send reports to Rollbar when using that framework.

  The blocks passed to `execute` are always executed after `Rollbar.configure` has been called in any of your initializer files or configuration files, so you are sure the `Rollbar.configuration` in your `execute` blocks is valid and what you expect to be.

- `execute!` is used on your plugin definition in those cases where you need to execute a block of code before `Rollbar.configure` is called. So in the moment the plugin file is read, that happens on a `require 'rollbar'` statement, the block passed to `execute!` is called.

  This is useful in those cases when the framework initialization needs your plugin to be attached to some hooks or any initialization process. This is what happens for example in the Rails plugin, where we need to define our own engine and that needs to be done before the `Rollbar.configure` call.

## Examples

The best way to understand how to build other plugins for the gem is taking a look into our existing plugins code, in https://github.com/rollbar/rollbar-gem/tree/master/lib/rollbar/plugins. If you have any doubt about how to define a new plugin, please, open an issue in the gem repository and we'll be very glad to help you!
