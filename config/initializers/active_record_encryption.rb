# Single-user local app: derive the encryption keys from secret_key_base
# instead of managing separate credentials.
Rails.application.config.active_record.encryption.tap do |enc|
  enc.primary_key = Rails.application.secret_key_base[0, 32]
  enc.deterministic_key = Rails.application.secret_key_base[32, 32]
  enc.key_derivation_salt = Rails.application.secret_key_base[64, 32]
end
