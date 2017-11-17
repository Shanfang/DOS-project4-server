defmodule App do
    def main() do
        loop(1)
    end

    def loop(n) when n > 0 do            
        Coordinator.start_link
        loop(n - 1)
    end

    def loop(n) do
        :timer.sleep 1000
        loop(n)
    end
end
