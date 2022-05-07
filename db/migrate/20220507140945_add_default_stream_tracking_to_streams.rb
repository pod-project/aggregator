class AddDefaultStreamTrackingToStreams < ActiveRecord::Migration[7.0]
  def change
    add_column :streams, :default_start_time, :timestamp
    add_column :streams, :default_end_time, :timestamp
  end
end
