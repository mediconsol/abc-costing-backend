class CreateJwtDenylists < ActiveRecord::Migration[8.0]
  def change
    create_table :jwt_denylists, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :jti, null: false
      t.datetime :exp

      t.timestamps
    end
    
    add_index :jwt_denylists, :jti, unique: true
    add_index :jwt_denylists, :exp
  end
end
