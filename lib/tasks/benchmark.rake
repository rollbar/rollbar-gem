require 'benchmark'

namespace :benchmark do
  desc 'Measure TracePoint perf for current Ruby'
  task :trace_point do
    ARGV.each { |a| task(a.to_sym { ; }) } # Keep rake from treating these ask task names.

    options = {}.tap do |hash|
      ARGV.each { |arg| hash[arg] = true }
    end

    puts "options: #{options}"

    trace_with_bindings = BenchmarkTraceWithBindings.new(options)

    trace_with_bindings.enable
    puts(Benchmark.measure do
      TraceTest.benchmark_with_locals
    end)
    trace_with_bindings.disable

    puts "counts: #{trace_with_bindings.counts}" if options['counts']
  end
end

class TraceTest # :nodoc:
  class << self
    def benchmark_with_locals
      foo = false

      (0..20_000).each do |index|
        foo = TraceTest

        change_frame_with_locals(foo, index)
      end
    end

    def change_frame_with_locals(foo, _index)
      foo.tap do |obj|
        bar = 'bar'
        hash = { :foo => obj, :bar => bar } # rubocop:disable Lint/UselessAssignment
      end
    end
  end
end

class BenchmarkTraceWithBindings # :nodoc:
  attr_reader :frames, :exception_frames, :options, :counts

  def initialize(options = {})
    @options = options
    @frames = []
    @exception_frames = []
    @exception_signature = nil
    @counts = init_counts({})
  end

  def init_counts(counts)
    [:call, :b_call, :c_call, :class].each do |event|
      counts[event] = 0
    end
    counts
  end

  def enable
    return if options['disable']

    trace_point.enable if defined?(TracePoint)
  end

  def disable
    return if options['disable']

    trace_point.disable if defined?(TracePoint)
  end

  def trace_point # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return unless defined?(TracePoint)

    @trace_point ||= TracePoint.new(:call, :return, :b_call, :b_return, :c_call,
                                    :c_return, :raise) do |tp|
      next if options['hook_only']

      case tp.event
      when :call, :b_call, :c_call, :class
        @counts[tp.event] += 1 if options['counts']
        frame = options['frame'] ? frame(tp) : {}
        frames.push frame if options['stack']
      when :return, :b_return, :c_return, :end
        frames.pop if options['stack']
      end
    end
  end

  def frame(trace)
    {
      :binding => trace.binding,
      :defined_class => trace.defined_class,
      :method_id => trace.method_id,
      :path => trace.path,
      :lineno => trace.lineno
    }
  end
end
