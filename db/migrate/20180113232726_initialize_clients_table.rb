class InitializeClientsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :clients do |t|
      t.text :key
      t.text :name
      t.text :link
    end

    create_table :chat_subscriptions do |t|
      t.integer :client_id
      t.integer :room_id
      t.integer :event_id
    end

    create_table :post_subscriptions do |t|
      t.integer :client_id
      t.text :post_type
      t.text :site
    end
  end
end
