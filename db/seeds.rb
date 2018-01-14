require './db'

c = Client.create(key: '12345', name: "tsm's bot")
c.chat_subscriptions.create(room_id: 63561)
c.post_subscriptions.create