RSpec::Matchers.define :be_eql_hash_with_regexes do |expected|
  def check_value(actual_value, expected_value)
    case expected_value
    when Hash
      expected_value.all? { |k, _| check_value(actual_value[k], expected_value[k]) }
    when Array
      expected_value.each_with_index.map do |v, i|
        check_value(actual_value[i], v)
      end.all?
    when Regexp
      actual_value.match(expected_value)
    else
      actual_value == expected_value
    end
  end

  match do |actual|
    expected.all? do |key, expected_value|
      actual_value = actual[key]

      check_value(actual_value, expected_value)
    end
  end
end
