class AddIsbnToMarcRecord < ActiveRecord::Migration[6.0]
  def change
    add_column :marc_records, :isbn, :string
    add_index :marc_records, :isbn
  end
end
