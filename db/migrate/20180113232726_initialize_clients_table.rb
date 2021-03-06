class InitializeClientsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :clients do |t|
      t.text :key
      t.text :name
      t.text :link
      t.datetime :last_ping
      t.text :status
    end

    create_table :chat_subscriptions do |t|
      t.integer :client_id
      t.integer :room_id
      t.integer :event_id
    end

    create_table :post_subscriptions do |t|
      t.integer :client_id
      t.text :type
      t.text :site
    end
  end
end
