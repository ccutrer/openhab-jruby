# frozen_string_literal: true

RSpec.describe OpenHAB::DSL::Items::LocationItem do
  subject(:item) { Location1 }

  before do
    items.build do
      location_item 'Location1', state: '30,20'
      location_item 'Location2', state: '40,20'
    end
  end

  describe 'can be updated' do
    specify { expect((item << '30,20').state).to eq '30,20' }
    specify { expect((item << '30,20,80').state).to eq '30,20,80' }
    specify { expect((item << PointType.new('40,20')).state).to eq '40,20' }
    specify { expect((item << { lat: 30, long: 30 }).state).to eq '30,30' }
    specify { expect((item << { latitude: 30, longitude: 30 }).state).to eq '30,30' }
    specify { expect((item << { lat: 30, long: 30, alt: 80 }).state).to eq '30,30,80' }
    specify { expect((item << { latitude: 30, longitude: 30, altitude: 80 }).state).to eq '30,30,80' }
  end

  it 'aliases `-` to `distance_from`' do
    expect((Location1 - Location2).to_i).to be 1_113_194
  end

  describe '#distance_from accepts supported types' do
    specify { expect(Location1.distance_from(Location2).to_i).to be 1_113_194 }
    specify { expect(Location1.distance_from(Location2.state).to_i).to be 1_113_194 }
    specify { expect(Location1.distance_from('40,20').to_i).to be 1_113_194 }
    specify { expect(Location1.distance_from({ lat: 40, long: 20 }).to_i).to be 1_113_194 }
    specify { expect(Location1.distance_from({ latitude: 40, longitude: 20 }).to_i).to be 1_113_194 }
    specify { expect(Location1.distance_from(PointType.new('40,20')).to_i).to be 1_113_194 }
    specify { expect(Location2.distance_from(Location1).to_i).to be 1_113_194 }
    specify { expect(Location2.state.distance_from(Location1).to_i).to be 1_113_194 }
    specify { expect(PointType.new('40,20').distance_from(Location1).to_i).to be 1_113_194 }
  end
end
