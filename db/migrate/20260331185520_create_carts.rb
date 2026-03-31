class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      t.references :user, null: true, foreign_key: true  # null for guest carts
      t.string :session_token
      t.datetime :expires_at

      t.timestamps
    end

    add_index :carts, :session_token
  end
end
