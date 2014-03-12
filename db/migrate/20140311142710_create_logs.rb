class CreateLogs < ActiveRecord::Migration
  def change
    create_table :logs do |t|
      t.string :user
      t.string :page

      t.timestamps
    end
  end
end
