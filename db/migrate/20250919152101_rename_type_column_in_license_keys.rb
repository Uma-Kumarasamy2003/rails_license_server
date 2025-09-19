class RenameTypeColumnInLicenseKeys < ActiveRecord::Migration[7.0]
  def change
    rename_column :license_keys, :type, :license_type
  end
end
