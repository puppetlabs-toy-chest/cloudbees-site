require 'net/http'

describe 'wordpress application' do
  it 'should respond with 302 redirect to web based installer' do
    ip = ENV['WORDPRESS_HOST']
    url = "http://#{ip}"

    uri = URI.parse(url)
    http = Net::HTTP.new( uri.host, uri.port)
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
  
    expect(response.code).to eq("302")
    expect(response['location']).to eq("#{url}/wp-admin/install.php")
  end
end
