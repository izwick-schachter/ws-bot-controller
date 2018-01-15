require 'faye/websocket'
require 'json'
require 'chatx'
require 'se/realtime'
require 'se/api'
require 'yaml'
require 'time'

require './db'

config = YAML.load_file('./config.yml')
cb = ChatBot.new(config['ChatXUsername'], config['ChatXPassword'])
cli = SE::API::Client.new(config['APIKey'])

cb.login
cb.join_rooms(ChatSubscription.all.map(&:room_id))

cb.add_hook('*', '*') do |event, room_id|
  WSClient.clients.each do |c|
    next if c.client.nil?
    c.client.chat_subscriptions.where(room_id: room_id, event_id: [event.type, nil]).each do |s|
      c.send(msg: event.hash)
    end
  end
  puts "Got #{event.type} in #{room_id} (#{event})"
end

def load_thresholds
  # Generate a hash with a default of 1
  t = Hash.new {|h, k| h[k] = 1 }
  YAML.load_file('thresholds.yml').map do |k, v|
    t[k] = v
  end
  t # I know this is bad, but I need the defaults set correctly
end

queue = Hash.new {|hsh, key| hsh[key] = []}
posts = Hash.new {|hsh, key| hsh[key] = []}
thresholds = load_thresholds

SE::Realtime.json do |e|
  id = e[:id]
  site = e[:site]
  # Adds the post ID to the queue of ids
  queue[site] << [id, Time.now]
  if queue[site].length >= thresholds[site]
    puts "Clearing queue on #{site} (#{queue[site]})"
    ftime = queue[site].map { |i| i[1] }.sort.first
    cli.questions(queue[site].map(&:first), site: site).each do |question|
      puts "Begining iteration on a question for site #{site}"
      answers = question.answers
      posts[site] << [question, answers].flatten
      new_posts = [question, answers].flatten.select { |p| Time.new(p.updated_at) > ftime }
      puts "New posts on question: #{new_posts.length}"
      new_posts.each do |p|
        WSClient.clients.each do |c|
          next if c.client.nil?
          type = case p
          when SE::API::Question
            'question'
          when SE::API::Answer
            'answer'
          end
          puts "Sending new post #{p.id} (gotta check subs)"
          c.client.post_subscriptions.where(site: [site, nil], type: [type, nil]).each do |s|
            puts "Sending new post #{p.id}"
            c.send(post: p.json)
          end
        end
      end
    end
    queue.delete(site)
  end
end

module HashRefinements
  refine Hash do
    def on(k, &block)
      Thread.new { block.call(self[k]) } if key? k
    end
  end
end


class WSClient
  using HashRefinements

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
  
  attr_reader :authenticated, :client

  def initialize(ws, cb)
    @cb = cb
    @authenticated = false
    @ws = ws
    @ws.on :message do |event|
      puts "Got msg: #{event.data}"
      if @authenticated || authenticate(event.data)
        send "You're #{@client.name}"
        parse(event.data)
      end
    end
    self.class.clients << self
  end

  def authenticate(key)
    @client = Client.find_by(key: key)
    if !@client.nil?
      @authenticated = true
      send status: 'sucess', bot: @client.name
    else
      send status: 'failed'
    end
    false
  end

  def send(msg)
    return unless @authenticated
    msg = msg.to_json if msg.is_a? Hash
    puts "Sending #{msg;nil} (#{msg.class})"
    @ws.send(msg)
  end

  private

  def parse(text)
    json = JSON.parse(text)
    unless json.is_a? Hash
      send status: 'invalid', msg: "You didn't send correct JSON"
      return
    end
    unless @client
      send status: 'not authenticated', msg: "You haven't authenticated yourself"
      return
    end
    json.on 'say' do |msg|
      if @cb.say("[#{@client.name}] #{msg}", 63561)
        log "Saying '#{msg}'"
        send action: 'say', sucess: true, msg: msg
      end
    end
    json.on 'ts' do
      time = Time.now.to_s
      log "Telling timestamp '#{time}'"
      send action: 'ts', sucess: true, time: time
    end
    json.on 'ping' do
      last_ping = DateTime.now
      if @client.update(last_ping: last_ping)
        log "Updating ping to #{last_ping}"
        send action: 'ping', sucess: true, last_ping: last_ping
      else
        send action: 'ping', sucess: false
      end
    end
    json.on 'status' do |status|
      if @client.update(status: status)
        log "Updated status to be #{status}"
        send action: 'status', sucess: true, status: status
      else
        send action: 'status', sucess: false
      end
    end
  end

  def log(msg)
    puts "[#{@client.name}] #{msg}"
  end
end

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    ws.on(:open) { puts "OPENED" }

    WSClient.new(ws, cb)

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
