# We want to use Gem.path
require 'rubygems'

module Rollbar
  class Item
    # Representation of the trace data per frame in the payload
    class Frame
      attr_reader :backtrace
      attr_reader :frame
      attr_reader :configuration

      MAX_CONTEXT_LENGTH = 4

      def initialize(backtrace, frame, options = {})
        @backtrace = backtrace
        @frame = frame
        @configuration = options[:configuration]
      end

      def to_h
        # parse the line
        match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)

        return unknown_frame unless match

        filename = match[1]
        lineno = match[2].to_i
        frame_data = {
          :filename => filename,
          :lineno => lineno,
          :method => match[3]
        }

        frame_data.merge(extra_frame_data(filename, lineno))
      end

      private

      def unknown_frame
        { :filename => '<unknown>', :lineno => 0, :method => frame }
      end

      def extra_frame_data(filename, lineno)
        file_lines = backtrace.get_file_lines(filename)

        return {} if skip_extra_frame_data?(filename, file_lines)

        {
          :code => code_data(file_lines, lineno),
          :context => context_data(file_lines, lineno)
        }
      end

      def skip_extra_frame_data?(filename, file_lines)
        config = configuration.send_extra_frame_data
        missing_file_lines = !file_lines || file_lines.empty?

        return false if !missing_file_lines && config == :all

        missing_file_lines ||
          config == :none ||
          config == :app && outside_project?(filename)
      end

      def outside_project?(filename)
        project_gem_paths = configuration.project_gem_paths
        inside_project_gem_paths = project_gem_paths.any? do |path|
          filename.start_with?(path)
        end

        # The file is inside the configuration.project_gem_paths,
        return false if inside_project_gem_paths

        root = configuration.root
        inside_root = root && filename.start_with?(root.to_s)

        # The file is outside the configuration.root
        return true unless inside_root

        # At this point, the file is inside the configuration.root.
        # Since it's common to have gems installed in {root}/vendor/bundle,
        # let's check it's in any of the Gem.path paths
        Gem.path.any? { |path| filename.start_with?(path) }
      end

      def code_data(file_lines, lineno)
        file_lines[lineno - 1]
      end

      def context_data(file_lines, lineno)
        {
          :pre => pre_data(file_lines, lineno),
          :post => post_data(file_lines, lineno)
        }
      end

      def post_data(file_lines, lineno)
        from_line = lineno
        number_of_lines = [from_line + MAX_CONTEXT_LENGTH, file_lines.size].min - from_line

        file_lines[from_line, number_of_lines]
      end

      def pre_data(file_lines, lineno)
        to_line = lineno - 2
        from_line = [to_line - MAX_CONTEXT_LENGTH + 1, 0].max

        file_lines[from_line, (to_line - from_line + 1)].select { |line| line && !line.empty? }
      end
    end
  end
end
