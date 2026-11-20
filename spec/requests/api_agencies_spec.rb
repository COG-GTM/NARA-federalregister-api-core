require "spec_helper"

RSpec.describe "Agencies Endpoint", :type => :request do
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    parent = Factory(:agency, name: "Parent Agency", slug: "parent-agency")
    Factory(:agency, name: "Child Agency", slug: "child-agency", parent: parent)
  end

  it "returns every agency ordered by name with its children" do
    get '/api/v1/agencies.json'

    expect(response.status).to eq(200)
    data = JSON.parse(response.body)
    expect(data.map { |a| a["name"] }).to eq(["Child Agency", "Parent Agency"])
    expect(data.last["child_slugs"]).to eq(["child-agency"])
  end

  it "serves the same body from cache and reflects agency changes" do
    get '/api/v1/agencies.json'
    first_body = response.body

    get '/api/v1/agencies.json'
    expect(response.body).to eq(first_body)

    Agency.find_by_slug("child-agency").update!(name: "Renamed Agency", updated_at: 1.minute.from_now)
    get '/api/v1/agencies.json'
    expect(JSON.parse(response.body).map { |a| a["name"] }).to eq(["Parent Agency", "Renamed Agency"])
  end

  it "keeps requested fields and JSONP callbacks separate from the cached default" do
    get '/api/v1/agencies.json'
    get '/api/v1/agencies.json', params: {fields: ["slug"], callback: "cb"}

    expect(response.media_type).to eq("application/javascript")
    expect(response.body).to start_with("cb(").and end_with(")")
    data = JSON.parse(response.body[3..-2])
    expect(data.map(&:keys)).to all(eq(["slug", "json_url"]))
    expect(data.map { |a| a["slug"] }).to eq(["child-agency", "parent-agency"])
  end
end
