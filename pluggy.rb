require 'faye/websocket'
require 'json'
require 'chatx'
require 'se/realtime'
require 'se/api'
require 'yaml'

config = YAML.load_file('./config.yml')
cb = ChatBot.new(config['ChatXUsername'], config['ChatXPassword'])
cli = SE::API::Client.new(config['APIKey'])

cb.login
cb.join_room(63561)

def load_thresholds
  # Generate a hash with a default of 1
  t = Hash.new {|h, k| h[k] = 1 }
  YAML.load_file('thresholds.yml').map do |k, v|
    t[k] = v
  end
  t # I know this is bad, but I need the efaults set correctly
end

queue = Hash.new {|hsh, key| hsh[key] = []}
posts = Hash.new {|hsh, key| hsh[key] = []}
thresholds = load_thresholds

SE::Realtime.json do |e|
  id = e[:id]
  site = e[:site]
  # Adds the post ID to the queue of ids
  queue[site] << id
  if queue[site].length >= thresholds[site]
    cli.questions(queue[site], site: site).each do |question|
      Client.send_authenticated(question: question.json, answers: question.answers.map(&:json))
      #question_posts = question.answswers.push(question)
      #puts '='*80
      #question_posts.each do |post|
      #  puts "#{post.class} #{post.last_activity_date} #{post.title}"
      #end
      #puts '='*80
      #post = question_posts.sort_by(&:last_activity_date).first
      #reports_for(post).each do |report|
      #  puts report
      #  cb.say(report, 63561)
      #end
    end
  end
end

class Client
  class << self
    def clients
      @clients ||= []
    end

    def push(client)
      @clients ||= []
      @clients.push(client)
    end

    def <<(client)
      @clients ||= []
      @clients << client
    end

    def send_authenticated(msg)
      @clients ||= []
      @clients.each { |c| c.send msg if c.authenticated }
    end
  end
  
  attr_reader :authenticated

  def initialize(ws, cb)
    @cb = cb
    @authenticated = false
    @ws = ws
    @config = {} # rooms: ; .... STEAL FROM QUART
    @ws.on :message do |event|
      puts "Got msg: #{event.data}"
      if @authenticated || authenticate(event.data)
        send "You're #{@user[0]}"
        parse(event.data)
      end
    end
    self.class.clients << self
  end

  def authenticate(key)
    @user = keys.select { |k, v| key == v }.to_a[0]
    if !@user.nil?
      @authenticated = true
      send status: 'sucess', bot: @user[0]
    else
      send status: 'failed'
    end
    false
  end

  def send(msg)
    return unless @authenticated
    msg = msg.to_json if msg.is_a? Hash
    puts "Sending #{msg} (#{msg.class})"
    @ws.send(msg)
  end

  private

  def keys
    {bota: 'abcde', botb: '12345'}
  end

  def parse(text)
    json = JSON.parse(text)
    unless json.is_a? Hash
      send status: 'invalid', msg: "You didn't send correct JSON"
      return
    end
    case json["action"]
    when "say"
      msg = json['msg']
      puts "Saying '#{msg}'"
      @cb.say("[#{@user[0]}] #{msg}", 63561)
      send complete: true, msg: msg
    when "ts"
      time = Time.now.to_s
      puts "Telling timestamp '#{time}'"
      send time: time
    end
  end
end

#SE::Realtime.json do |data|
#  Client.clients.each { |c| c.send action: 'post', data: data }
#end

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    ws.on(:open) { puts "OPENED" }

    Client.new(ws, cb)

    ws.on :close do |event|
      p [:close, event.code, event.reason]
      ws = nil
    end

    # Return async Rack response
    ws.rack_response

  else
    # Normal HTTP request
    [200, {'Content-Type' => 'text/plain'}, ['Hello']]
  end
end
