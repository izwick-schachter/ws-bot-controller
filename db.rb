require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database  => "db.sqlite3"
)

class Client < ActiveRecord::Base
  has_many :chat_subscriptions
  has_many :post_subscriptions
end

class ChatSubscription < ActiveRecord::Base
  belongs_to :client
end

class PostSubscription < ActiveRecord::Base
  belongs_to :client
end