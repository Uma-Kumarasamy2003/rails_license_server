class CreateLicenseKeys < ActiveRecord::Migration[7.2]
  def change
    create_table :license_keys do |t|
      t.string :key
      t.string :assignedTo
      t.datetime :startDate
      t.datetime :endDate
      t.string :deviceId
      t.string :status
      t.string :type

      t.timestamps
    end
    add_index :license_keys, :key, unique: true
  end
end
