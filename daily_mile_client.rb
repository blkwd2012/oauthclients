class DailyMileClient
  
  def initialize(user)
    @user = user
    if(@account = DailyMileClient.has_credentials?(user))
      client = OAuth2::Client.new(APP_CONFIG[:daily_mile_client_id], APP_CONFIG[:daily_mile_client_secret], :site => 'https://api.dailymile.com', :authorize_url => 'https://api.dailymile.com/oauth/authorize', :token_url => 'https://api.dailymile.com/oauth/token')
      @access_token = OAuth2::AccessToken.new(client, @account.credentials[:access_token])
      @daily_mile_username = info["username"]
    else
      @client = OAuth2::Client.new(APP_CONFIG[:daily_mile_client_id], APP_CONFIG[:daily_mile_client_secret], :site => 'https://api.dailymile.com', :authorize_url => 'https://api.dailymile.com/oauth/authorize', :token_url => 'https://api.dailymile.com/oauth/token')
    end
  end
  
  def self.name
    "DailyMile"
  end
  
  def authorize_url
    @client.auth_code.authorize_url(:redirect_uri => APP_CONFIG[:daily_mile_redirect_uri])
  end
  
  def self.has_credentials?(user)
    @account = user.accounts.where(:account_type => "DailyMile").first
  end
  
  def client
    @client
  end
  
  def verify!(user, authorization_code)
    begin
      access_token = @client.auth_code.get_token(authorization_code, :redirect_uri => APP_CONFIG[:daily_mile_redirect_uri])
      user.accounts.create(:account_type => DailyMileClient.name, :credentials => { :access_token => access_token.token })
    rescue OAuth2::Error => e
      raise "Oops, OAuth session on #{DailyMileClient.name} failed because of #{e.code.classify}. Try to authorize again."
    end
  end
  
  def self.disconnect!(user)
    user.accounts.where(:account_type => "DailyMile").destroy_all
  end
  
  def authenticated?
    !!@account
  end
  
  class << self
    alias :authenticated? has_credentials?
  end
  
  def info
    get("/people/me")
  end
  
  def find_entries
    get "/people/#{@daily_mile_username}/entries"
  end
  
  def find_routes
    get "/people/#{@daily_mile_username}/routes", false
  end
  
  def find_entries_by_date(date = Date.today)
    entries_of_today = []
    find_entries["entries"].each do |entry|
      if entry["at"].to_date == date
        entries_of_today << entry
      end
    end
    entries_of_today
  end
  
  def find_route_by_id(id)
    resp = connection.get "routes/#{id}.gpx"
    resp.body
  end
  
  def sync
    sync_entries
  end
  
  def sync_entries
    find_entries_by_date.each do |e|
      puts e["workout"]["activity_type"]
    end
  end
  
  protected 
  
  def connection
    @@connection ||= Faraday.new(:url => 'https://api.dailymile.com', :headers => { :accept =>  'application/json'}) do |builder|
      builder.adapter  :net_http
    end
  end
  
  def get(path, with_access_token = true)
    response = connection.get do |req|
      req.url path <<".json"
      if with_access_token == true
        req.params['oauth_token'] = @access_token.token
      end
    end
    extract_response_body response
  end
  
  def extract_response_body(resp)
    resp.nil? || resp.body.nil? ? {} : JSON.parse(resp.body)
  end
end