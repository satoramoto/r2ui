# frozen_string_literal: true

# Background work: a slow job every 3 seconds while the clock keeps ticking.
#   exe/r2ui examples/dsl/async.rb

R2UI.dashboard do
  every 0.1 do
    state[:frames] = state[:frames].to_i + 1
  end

  every 3 do
    state[:busy] = true
    async(lambda {
      sleep 2
      raise "unlucky roll" if rand < 0.3

      rand(1..6)
    }) do |roll, error|
      state[:busy] = false
      state[:last] = error ? "failed: #{error.message}" : "rolled #{roll}"
    end
  end

  row do
    panel :job, resource: nil do
      view do
        <<~TEXT
          frames drawn: #{state[:frames].to_i}
          #{state[:busy] ? "rolling..." : "idle"}
          last: #{state[:last] || "-"}
        TEXT
      end
    end
  end
end
