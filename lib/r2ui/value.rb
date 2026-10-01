# frozen_string_literal: true

module R2UI
  # Rows can be hashes, Data/Struct objects or ActiveRecord models; read them all the same way.
  module Value
    module_function

    def fetch(row, key)
      case row
      when Hash then row.key?(key) ? row[key] : row[key.to_s]
      else row.public_send(key)
      end
    end
  end
end
