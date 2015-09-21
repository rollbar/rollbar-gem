require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb'

OJ_VERSION = '~> 2.12.14'

def jruby?
  defined?(JRUBY_VERSION) || (defined?(RUBY_ENGINE) && 'jruby' == RUBY_ENGINE)
end

def install_oj
  begin
    Gem::Command.build_args = ARGV

    unless jruby?
      $stdout.write "Installing oj because platform is not JRuby\n"

      di = Gem::DependencyInstaller.new
      di.install 'oj', OJ_VERSION
    end
  rescue => e
    warn "#{$0}: #{e}"

    exit!
  end
end

def write_rakefile
  $stdout.write "Writing fake Rakefile\n"

  # Write fake Rakefile for rake since Makefile isn't used
  File.open(File.join(File.dirname(__FILE__), 'Rakefile'), 'w') do |f|
    f.write('task :default' + $/)
  end
end

install_oj
write_rakefile
