class AddTime < ActiveRecord::Migration
  def change
      add_column :logs, :time, :integer
  end
end
