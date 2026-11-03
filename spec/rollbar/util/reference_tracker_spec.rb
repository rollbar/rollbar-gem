require 'spec_helper'
require 'rollbar/util/reference_tracker'

describe Rollbar::Util::ReferenceTracker do
  subject(:tracker) { described_class.new(10) }

  let(:container) { { :a => 1, :b => 2, :c => 3 } }

  def see(container)
    tracker.track(container) { nil }
  end

  it 'never charges a container seen for the first time' do
    expect(tracker.copy_allowed?(container, 100)).to be(true)
  end

  it 'charges a repeated container for each of its entries' do
    see(container)

    3.times { expect(tracker.copy_allowed?(container, 3)).to be(true) }
    expect(tracker.copy_allowed?(container, 3)).to be(false)
  end

  it 'still allows a smaller repeated container after refusing a larger one' do
    see(container)

    expect(tracker.copy_allowed?(container, 11)).to be(false)
    expect(tracker.copy_allowed?(container, 10)).to be(true)
    expect(tracker.copy_allowed?(container, 1)).to be(false)
  end

  it 'treats only containers on the current path as circular' do
    tracker.track(container, :copy) do
      expect(tracker.circular?(container)).to be(true)
      expect(tracker.copy_of(container)).to eq(:copy)
    end

    expect(tracker.circular?(container)).to be(false)
  end
end
