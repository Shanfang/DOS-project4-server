defmodule Coordinator do
    use GenServer
    @name SERVER
    ######################### client API ####################
    #def start_link do
    #    GenServer.start_link(__MODULE__, %{}, [name: :coordinator])
    #end
    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, %{}, opts ++ [name: SERVER])        
    end

    # userID is a string
    def register_account(userID) do
        GenServer.call(@name, {:register_account, userID})        
    end

    def send_tweet(tweet, userID) do
        GenServer.cast(@name, {:process_tweet, tweet, userID})
    end

    def subscribe(to_subscribe_ID, userID) do
        GenServer.call(@name, {:subscribe, to_subscribe_ID, userID})        
    end

    def re_tweet(tweet, userID) do
        GenServer.call(@name, {:process_tweet, tweet, userID})
    end

    def query_tweet(query, userID) do
        GenServer.call(@name, {:query_tweet, query, userID})        
    end

    def connect(userID) do
        GenServer.call(@name, {:connect, userID})                
    end

    ######################### callbacks ####################
    
    # init the server with an empty table to store clients
    def init(%{}) do
        state = %{"usertable" => nil, "hash_tage_table" => nil, "mention_table" => nil}
        user_table = :ets.new(:user_table, [:named_table, protected: true, read_concurrency: true])
        hash_tage_table = :ets.new(:hash_tage_table,[:named_table, protected: true, read_concurrency: true])
        mention_table = :ets.new(:mention_table,[:named_table, protected: true, read_concurrency: true])
        new_state = %{state | "usertable" => user_table, "hash_tage_table" => hash_tage_table, "mention_table" => mention_table}
        {:ok, new_state}
    end

    # insert userID to user_table if it has not registered, otherwise make no change to the table
    def handle_call({:register_account, userID}, _from, state) do
        case find_user(userID, state) do
            {:ok, {followers_list, followings_list, tweets_list}} ->
                {:reply, userID, state} # already registered
            :error ->
                user_table = state["user_table"]
                :ets.insert(user_table, {userID, [], [], []}) # register as a new user
                new_state = %{state | "user_table" => user_table}
                {:reply, userID, new_state}
        end
    end

    @doc """
        Assuming the user is registered, so there is no need to check if the user exists in user_table
    """
    def handle_cast({:process_tweet, tweet, userID}, state) do
        user_table = update_tweets_list(tweet, state["user_table"], userID)
        
        followers_list = :ets.lookup(state["user_table"], userID) # get a list of tuples[{}]
                            |> List.first # get a tuple {userID, followers_list, followings_list, tweets_list}
                            |> elem(1) # get the followers_list
        user_table = send_to_followers(tweet, state["user_table"], followers_list, length(followers_list))
        state = 
            case tweet_type(tweet) do
                {:hash_tage, tag} ->
                    hash_tage_table = state["hash_tage_table"]
                    :ets.insert(hash_tage_table, {tag, tweet})
                    %{state | "hash_tage_table" => hash_tage_table}
                {:mention, mention} ->
                    mention_table = state["mention_table"]       
                    :ets.insert(mention_table, {mention, tweet})
                    %{state | "mention_table" => mention_table}             
            end
        new_state = %{state | "user_table" => user_table}
        {:noreply, new_state}
    end


    def handle_call({:subscribe, to_subscribe_ID, userID}, _from, state) do
        user_table = state["user_table"]
        tuple = :ets.lookup(user_table, userID)
        case find_user(to_subscribe_ID, state) do
            {:ok, followers_list, followings_list, tweets_list} ->
                :ets.insert(user_table, {userID, elem(tuple, 1), [to_subscribe_ID | elem(tuple, 2)], elem(tuple, 3)})
                :ets.insert(user_table, {to_subscribe_ID, [userID | followers_list], followings_list, tweets_list})             
            :error ->
                IO.puts "Sorry, the user you are subscribing to does not exist."
        end

        new_state = %{state | "user_table" => user_table}
        
        # TO IMPLEMENT ====> need to push to_subscribe_ID's tweets to userID  
        {:reply, userID, new_state}
    end
    @doc """
        First, check if the user is registered, if not, register it
        Otherwise, subscrib to designated user and make changes to user_table for both entries
   
    def handle_call({:subscribe, to_subscribe_ID, userID}, _from, user_table) do
        case find_user(userID) do
            {:ok, followers_list1, followings_list1, tweets_list1} ->
                case find_user(to_subscribe_ID) do
                    {:ok, followers_list2, followings_list2, tweets_list2} ->
                        :ets.insert(user_table, {userID, followers_list1, [to_subscribe_ID | followings_list1], tweets_list1})
                        :ets.insert(user_table, {to_subscribe_ID, [userID | followers_list2], followings_list2, tweets_list2})             
                    :error ->
                        IO.puts "Sorry, the user you are subscribing to does not exist."
                end
               
               # TO IMPLEMENT ====> need to push to_subscribe_ID's tweets to userID  
                {:reply, userID, user_table}
            :error ->
                IO.puts "You have not registered yet, registering now..."
                :ets.insert(user_table, {userID, [], [], []})               
                {:reply, userID, user_table}
        end
    end
    """
    ######################### helper functions ####################

    defp find_user(userID, state) do
        case :ets.lookup(state["user_table"], userID) do
            [{^userID, followers_list, followings_list, tweets_list}] -> 
                {:ok, followers_list, followings_list, tweets_list}
            [] -> 
                :error
        end
    end

    defp update_tweets_list(tweet, user_table, userID) do
        value_tuple = :ets.lookup(user_table, userID) |> List.first 
        tweets_list = [tweet | elem(value_tuple, 3)]
        :ets.insert(user_table,{userID, elem(value_tuple, 1), elem(value_tuple, 2), tweets_list})
        user_table
    end

    defp send_to_followers(tweet, user_table, followers_list, count) when count > 0 do     
        follower = List.first(followers_list)

        # delete from the front of the list
        followers_list = List.delete_at(followers_list, 0) 

        # list of tuple[{}], then get the first tuple {follower, [], [], []}
        value_tuple = :ets.lookup(user_table, follower) |> List.first 
        
        # get follower's tweet list then prepend tweet to the list
        tweets_list = elem(value_tuple, 3) 
        tweets_list = [tweet | tweets_list]
        :ets.insert(user_table,{follower, elem(value_tuple, 1), elem(value_tuple, 2), tweets_list})
        send_to_followers(tweet, user_table, followers_list, count - 1)
    end
    
    defp send_to_followers(tweet, user_table, followers_list, count) do
        user_table
    end

    defp tweet_type(tweet) do
        {:no_match}
    end
 end