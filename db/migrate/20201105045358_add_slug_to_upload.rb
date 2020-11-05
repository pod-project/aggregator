class AddSlugToUpload < ActiveRecord::Migration[6.0]
  def change
    add_column :uploads, :slug, :string
    add_index :uploads, :slug
  end
end
