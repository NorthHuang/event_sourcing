# frozen_string_literal: true

RSpec.describe EventSourcing::Helpers::AttributeSupport do
  let(:klass) do
    Class.new do
      include EventSourcing::Helpers::AttributeSupport

      attrs :enabled, Boolean
      attrs :count, Integer
    end
  end

  it "updates false values" do
    instance = klass.new

    instance.update_attributes_with_type(enabled: false)

    expect(instance.enabled).to be(false)
  end

  it "casts string-keyed attributes" do
    instance = klass.new

    instance.update_attributes_with_type("count" => "3")

    expect(instance.count).to eq(3)
  end

  it "sets string-keyed attributes without type casting" do
    instance = klass.new

    instance.update_all_attributes("enabled" => false)

    expect(instance.enabled).to be(false)
  end

  it "leaves missing attributes unchanged when updating all attributes" do
    instance = klass.new
    instance.update_all_attributes(enabled: true, count: 1)

    instance.update_all_attributes(enabled: false)

    expect(instance.count).to eq(1)
  end
end
