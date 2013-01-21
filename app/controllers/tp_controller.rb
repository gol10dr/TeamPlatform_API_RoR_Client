require 'oauth2'
require 'json'

CLIENT_ID = TP_CONFIG['client_id']
CLIENT_SECRET = TP_CONFIG['client_secret'] 
REDIRECT_URI = "http://localhost:3000/callback/"


class TpController < ApplicationController

before_filter :auth_user, :only => :index

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  # Declare client to be used in handshake with TeamPlatform
  def client
    OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET, {
      :authorize_url => 'https://teamplatform.com/api/v1/oauth/authorize',
      :token_url => 'https://teamplatform.com/api/v1/oauth/access_token',
      :token_method => :post })
  end
 
  # Check if session has been set to access_token, otherwise, send for authorization
  def auth_user
    return redirect_to(:action => 'authorize') unless session[:access_token]
  end 
  
  # Send authorization request 
  def authorize
      redirect_to client.auth_code.authorize_url(:redirect_uri => REDIRECT_URI)
  end

  # Receive callback code and request access token
  def callback
    access_token = client.auth_code.get_token(params[:code], :redirect_uri => REDIRECT_URI)
    session[:access_token] = access_token.token
    redirect_to tp_index_url 
  end
  
  # Fetch url and parse JSON response
  def get_collection(path)
    uri = URI.parse(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.get(uri.request_uri)
    JSON.parse(response.body)
  end
  
  # Post JSON details to specified url based on method
  def post_collection(type, path, data)
    uri = URI.parse(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    if type == 'create' then
      req = Net::HTTP::Post.new(uri.request_uri)
      req.set_form_data(data)
    elsif type == 'delete' then
      req = Net::HTTP::Delete.new(uri.request_uri)
    elsif type == 'update' then    
      req = Net::HTTP::Put.new(uri.request_uri)
      req.set_form_data(data)
    end
    response = http.request(req)
  end
  
  # Get account information
  def index
   @atoken = session[:access_token]
   @profile = get_collection("https://teamplatform.com/api/v1/profile?access_token="+@atoken)
   @workspaces = get_collection("https://teamplatform.com/api/v1/workspaces?access_token="+@atoken)
   @files = get_collection("https://teamplatform.com/api/v1/files?access_token="+@atoken)
   @pages = get_collection("https://teamplatform.com/api/v1/pages?access_token="+@atoken)
   @comments = get_collection("https://teamplatform.com/api/v1/comments?access_token="+@atoken)
   @tasks = get_collection("https://teamplatform.com/api/v1/tasks?access_token="+@atoken)
  end
  
 
  # Create new workspace
  def create_workspace
    path = 'https://teamplatform.com/api/v1/workspaces?access_token='+ session[:access_token]
    data = {'title' => params[:title], 'description' => params[:description]}
    post = post_collection('create',path, data)
    redirect_to root_path
  end
  
  # Delete workspace
  def delete_workspace
    if params[:purge] == nil then
      path = "https://teamplatform.com/api/v1/workspaces/#{params[:id]}?access_token="+ session[:access_token]
    elsif params[:purge] == 'true' then
      path = "https://teamplatform.com/api/v1/workspaces/#{params[:id]}?access_token="+ session[:access_token] + '&purge=true'
    end
    post = post_collection('delete', path, '') 
    redirect_to root_path
  end
  
  # Update workspace
  def update_workspace
    path = "https://teamplatform.com/api/v1/workspaces/#{params[:id]}?access_token="+ session[:access_token]
    data = {'title' => params[:title], 'description' => params[:description], 'status' => 'active'}
    post = post_collection('update', path, data)
    redirect_to root_path
  end

end

