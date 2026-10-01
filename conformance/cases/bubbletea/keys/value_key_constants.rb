# The KeyMessage::KEY_* constants and their integer values.
require "bubbletea"

Bubbletea::KeyMessage.constants.grep(/\AKEY_/).sort_by { |c| [Bubbletea::KeyMessage.const_get(c), c] }
                     .map { |c| "#{c}=#{Bubbletea::KeyMessage.const_get(c)}" }.join("\n")
