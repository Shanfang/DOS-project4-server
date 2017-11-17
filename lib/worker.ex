defmodule Worker do
    use GenServer
    
    ######################### client API ####################

    def start_link(index, followers, followings, serverID) do
        worker_name = index |> Integer.to_string |> String.to_atom
        GenServer.start_link(__MODULE__, {index, followers, followings}, [name: worker_name])
    end

    def start_tweet(worker_name) do
        GenServer.cast(worker_name, {:start_tweet})
    end

    ######################### callbacks ####################

    def init({index, followers, followings, serverID}) do 
        # use the server nodeID to connect this client to server 
        state = %{id: 0, connected: false, followers: [], followings: [], tweets: []}
        
        status = connect_to_server(serverID)
        
        new_state = %{state | id: index, connected: status, followers: followers, followings: followings}
        {:ok, new_state}
    end
end