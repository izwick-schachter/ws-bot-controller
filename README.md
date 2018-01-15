# SE Bot Coordinator

Creates a websocket server that bots can attach to, submit status updates to, and interact with chat through. It saves on the API quota and saves the trouble of chat interactions and the realtime socket and all that nonsense.

Written in ruby, with the help from:

- SE interaction libraries:
  - [ChatX](https://gitlab.com/izwick-schachter/ChatX)
  - [se-api](https://github.com/izwick-schachter/se-api)
  - [se-realtime](https://github.com/izwick-schachter/se-realtime)
- WebSocket libraries:
  - [websocket-driver](https://rubygems.org/gems/websocket-driver)
  - [puma](https://rubygems.org/gems/puma)
  - [faye-websocket](https://rubygems.org/gems/faye-websocket)
- Database libraries:
  - [sqlite3](https://rubygems.org/gems/sqlite3)
  - [sinatra-activerecord](https://rubygems.org/gems/sintra-activerecord) (But **not** sinatra)
  - [activerecord](https://rubygems.org/gems/activerecord)
- Web Dashboard:
  - [pluggy](https://github.com/izwick-schachter/pluggy)

## Usage

First of all, you need a key. You can get one by pinging @thesecretmaster in SE chat. They can typically be found in [The Closet](https://chat.stackexchange.com/rooms/63296/the-closet) or [Under The Bed](https://chat.stackexchange.com/rooms/63561/under-the-bed). (Yes, this could be a security issue, but this project is just in a testing phase right now)

Second, open a WebSocket connection to the WebSocket server at smelly.dvtk.me. Currently, wss is not supported, so you've gotta use plain old ws. To authenticate, simply send your key down the socket. You should recieve a reply of the form: `{status: 'sucess', bot: <name of bot or nil>}`. If your key is invalid or another error has occured, you will recieve the message: `{status: 'failed'}`. If you recieve neither, you've discoved a bug -- open an issue or ping @thesecretmaster in chat.

As soon as you've been authenticated, the server will begin sending the posts and chat messages that you've subscribed to. They will look like this:

- Chat Message: `{msg: <chat message streight from the chat websocket>}`
- Post: `{post: <post streight from the SE API with all fields included>}`

You can also send messages to the server. The server accepts valid json. If the json is not valid, you will get the response `{status: 'invalid', msg: "You didn't send correct JSON"}`. Here is a list of the keys the server accepts and how it will respond. You can send multiple keys in one message, but each one will get an individual response. All responses will include an `action` key with the action called as the value:

- `ping: <anything>` => `{action: 'ping', sucess: true last_ping: <timestamp>}`
  - Updates last_ping time for the bot to the time listed in the reply. This last_ping time may be listed in the web interface
- `ts: <anything>` => `{action: 'ts', sucess: true time: <current server time>}`
  - Reports server time back to the bot.
- `status: <some text>` => `{action: 'status', sucess: true status: <status that was set>}`
  - Sets the bot status to the text sent. This status may be displayed on the web interface.
- `say: <some message>` => `{action: 'say', sucess: true, msg: <message that was sent>}`
  - Sends the message to the one and only chat room that is currently available, Under The Bed

If the action fails for any reason, a reply will be recieved of the form `{action: <the action>, sucess: false}`. If you recieve no response (within a second or two) report a bug either via an issue or by pinging @thesecretmaster in chat.