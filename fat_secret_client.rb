require 'hmac'

class FatSecretClient

  attr_accessor :client, :consumer, :user

  def initialize(user)
    @user = user
    key, secret = APP_CONFIG[:fat_secret_consumer_key], APP_CONFIG[:fat_secret_consumer_secret]

    if(@account = FatSecretClient.has_credentials?(user))
      @consumer = OAuth::Consumer.new(key, secret, { :site => "http://platform.fatsecret.com", :http_method => :get, :scheme => :query_string })
      @access_token = OAuth::AccessToken.new(@consumer, @account.credentials[:oauth_token], @account.credentials[:oauth_token_secret])
    else
      @consumer = OAuth::Consumer.new(key, secret, { :site => "http://www.fatsecret.com", :http_method => :get, :scheme => :query_string })
    end
  end

  def self.name
    "FatSecret"
  end  
  
  def client
    @access_token
  end
  
  def user
    @user
  end
  
  def info
    get({ :method => 'profile.get'})
  end

  def find_food_by_id(id)
    get({ :method => 'food.get', :food_id => id })
  end
  
  def find_recipe_by_id(id)
    get({ :method => 'recipe.get', :recipe_id => id })
  end
  
  def find_weights_by_month(date = Time.now.to_date)
    get({ :method => 'weights.get_month', :date => (date - Date.new(1970,1,1)).to_i })
  end
  
  def find_saved_meals(meal_type = nil)
    get({ :method => 'saved_meals.get', :meal => meal_type })
  end
  
  def find_food_entries_by_month(date = Time.now.to_date)
    get({ :method => 'food_entries.get_month', :date => (date - Date.new(1970,1,1)).to_i })
  end
  
  def find_food_entries_by_date(date = Time.now.to_date)
    get({ :method => 'food_entries.get', :date => (date - Date.new(1970,1,1)).to_i })
  end

  def request_token
    @request_token ||= @consumer.get_request_token({ :oauth_callback => APP_CONFIG[:fat_secret_callback] })
  end
  
  def request_secret
    @request_secret
  end
  
  def verify!(user, oauth_token, oauth_verifier, oauth_secrect)
    begin
      request_token = OAuth::RequestToken.new(consumer, oauth_token, oauth_secrect)
      @access_token = request_token.get_access_token({ :oauth_verifier => oauth_verifier })
      user.accounts.create(:account_type => FatSecretClient.name, :credentials => { :oauth_token => @access_token.token, :oauth_token_secret => @access_token.secret })
    rescue
      raise "Oops, there wasn't a valid OAuth session on #{FatSecretClient.name}. Try to authorize again."
    end
  end  

  def authorize_url
    @request_secret = request_token.secret
    request_token.authorize_url
  end
  
  def self.has_credentials?(user)
    user.accounts.where(:account_type => name).first
  end  
  
  def self.authenticated?(user)
    self.has_credentials?(user)
  end
  
  def authenticated?
    !!@account
  end
  
  def self.disconnect!(user)
    user.accounts.where(:account_type => "FatSecret").destroy_all
  end
  
  def sync
    sync_food_entries
  end
  
  def sync_food_entries
    unless find_food_entries_by_date['food_entries'].nil?
      food_entries = find_food_entries_by_date['food_entries']['food_entry']
      single_item_flag = true
      begin
        food_entries.has_key?("food_entry_description")
      rescue NoMethodError
        single_item_flag = false
      ensure
        if single_item_flag == true
          food_entries = [food_entries]
        end
        food_entries.each do |entry|
          @user.food_entries.create(:food_entry_id => entry["food_entry_id"], :description => entry["food_entry_description"], 
          :calories => entry["calories"], :reading_date => Date.today, :name => entry["food_entry_name"], :food_id => entry["food_id"],
          :meal => entry["meal"], :calcium => entry["calcium"], :carbohydrate => entry["carbohydrate"], :cholesterol => entry["cholesterol"],
          :fat => entry["fat"], :fiber => entry["fiber"], :iron => entry["iron"], :monounsaturated_fat => entry["monounsaturated_fat"],
          :unit => entry["number_of_units"], :polyunsaturated_fat => entry["polyunsaturated_fat"], :protein => entry["protein"],
          :saturated_fat => entry["saturated_fat"], :sodium => entry["sodium"], :vitamin_a => entry["vitamin_a"], 
          :vitamin_c => entry["vitamin_c"] )
        end
      end
    end    
  end
  
  protected
  
    def get(query_opts, headers={})
      defaults = { :format => 'json' }
      opts = defaults.merge(query_opts)
      extract_response_body client.get("/rest/server.api?#{opts.to_query}", headers)
    end
  
    def extract_response_body(resp)
      resp.nil? || resp.body.nil? ? {} : JSON.parse(resp.body)
    end

end  

