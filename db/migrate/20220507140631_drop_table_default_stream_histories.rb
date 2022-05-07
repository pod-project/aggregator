class DropTableDefaultStreamHistories < ActiveRecord::Migration[7.0]
  def change
    drop_table :default_stream_histories
  end
end
