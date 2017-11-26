defmodule Tester do
    use GenServer
  
    ######################### client API ####################
    def start_link do
        GenServer.start_link(__MODULE__, %{}, [name: :tester])
    end
    
    def register_account(tester) do
        GenServer.cast(tester, {:register})
    end
  
    ######################### callbacks ####################
  
    def init(%{}) do
        state = %{userID: "shanfang"}
        IO.puts "Start to connect to the server node.."
        {:ok, state}
    end
  
  
  
    def handle_cast({:register}, state) do
  
        Server.register_account("sf")
        {:ok, state}        
    end
  end
  