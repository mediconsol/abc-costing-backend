class EnableUuidExtension < ActiveRecord::Migration[8.0]
  def change
    # PostgreSQL에서만 UUID 확장 활성화
    if ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
      enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
      enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
    end
  end
end
