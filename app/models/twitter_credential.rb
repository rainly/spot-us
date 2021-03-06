require 'twitter'
 
class TwitterCredential < ActiveRecord::Base
    
  belongs_to :user
  validates_uniqueness_of :login, :on => :create, :message => "The username is already taken"
  validates_presence_of :login, :on => :create, :message => "The username cannot be blank"
  validates_presence_of :password, :on => :create, :message => "Password cannot be blank"
  validates_presence_of :user_id, :on => :create, :message => "User id cannot be blank"
  validate :check_connection

  def check_connection
    begin
      client = get_client
      status = client.timeline_for(:me)
      return true
    rescue Twitter::RESTError => re 
      errors.add_to_base("Oops, those credentials doesn't seem valid. Please check them.")
    rescue Twitter::Error
      errors.add_to_base("Oops, those credentials doesn't seem valid. Please check them.")
    end
  end
      
  def update?(status)
    obj = nil
    
    if UPDATE_USER_TWITTER
      begin
        client = get_client
        obj = update_status(client, status)
      rescue Twitter::RESTError => re 
        return raise_error?('REST ERROR', status)
      rescue Twitter::Error
        return raise_error?('ERROR', status)
      end
    else
      #get the user and email update
      obj = Mailer.deliver_notification_email(MAIL_WEBMASTER, "Update of Twitter for #{user.email} with email #{user.email}","Test Twitter update with this status: #{status}") if user
    end               
    
    obj
  end
  
  def raise_error?(type='ERROR', status='')
    Mailer.deliver_notification_email(MAIL_WEBMASTER, "Update of Twitter for #{user.email} with email #{user.email}", "Attempted Twitter update with this status: #{status}") if user
    logger.info("#{type}: Update of Twitter for #{user.email} with email #{user.email}") if user
    return false
  end
  
  def get_client
    Twitter::Client.new(:login => login,:password => password)
  end
  
  #updates twitter
  def update_status(client, status)
    request_status = nil
    begin
      request_status = client.status(:post, status)
    rescue Twitter::RESTError => re 
      logger.info(re.inspect)
    rescue Twitter::Error
    end
    return request_status
  end

end