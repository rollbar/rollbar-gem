require 'fileutils'

desc 'Update rollbar.js snippet'
task :update_snippet do
  input_path = File.expand_path("../../../rollbar.js/dist/rollbar.snippet.js", __FILE__)
  output_path = File.expand_path("../../../data/rollbar.snippet.js", __FILE__)
  output_dir = File.expand_path("../../../data/", __FILE__)

  $stdout.write("Copying #{input_path} to #{output_path}\n")

  FileUtils.mkdir_p(output_dir)
  FileUtils.copy(input_path, output_path)
end
