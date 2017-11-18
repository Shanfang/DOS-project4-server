defmodule Server do
    use GenServer
    @name SERVER
    ######################### client API ####################
    #def start_link do
    #    GenServer.start_link(__MODULE__, %{}, [name: :coordinator])
    #end
    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts ++ [name: SERVER])        
    end

    # userID is a string
    def register_account(userID) do
        GenServer.call(@name, {:register_account, userID}, :infinity)        
    end

    def send_tweet(tweet, userID) do
        GenServer.cast(@name, {:send_tweet, tweet, userID})
    end

    def subscribe(to_subscribe_ID, userID) do
        GenServer.call(@name, {:subscribe, to_subscribe_ID, userID}, :infinity)        
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
    def init(:ok) do
        #state = %{hash_tag_table: %{}, mention_table: %{}}
        #user_table = :ets.new(:user_table, [:named_table, protected: true, read_concurrency: true])
        #hash_tag_table = :ets.new(:hash_tag_table,[:named_table, protected: true, read_concurrency: true])
        #mention_table = :ets.new(:mention_table,[:named_table, protected: true, read_concurrency: true])
        :ets.new(:user_table, [:set, :named_table, :public])
        :ets.new(:hash_tag_table,[:bag, :named_table, :public])
        :ets.new(:mention_table,[:bag, :named_table, :public])
        #state = %{"usertable" => :user_table, "hash_tag_table" => :hash_tag_table, "mention_table" => :mention_table}
        #state = %{"usertable" => :user_table, "hash_tag_table" => %{}, "mention_table" => %{}} 
        {:ok, :ok}
        #{:ok, %{state |"usertable" => user_table, "hash_tag_table" => hash_tag_table, "mention_table" => mention_table}}
    end

    @doc """
    Insert userID to user_table if it has not registered, otherwise make no change to the table
    """
    def handle_call({:register_account, userID}, _from, state) do
        IO.puts "Current user_table is " 
        IO.inspect :ets.lookup(:user_table, userID)
        
        case user_status(userID) do
            :ok ->
                IO.puts "This user is already registered, please try another one."
            :error ->
                :ets.insert(:user_table, {userID, [], [], []}) # register as a new user
        end
        IO.puts "The updated user_table is " 
        IO.inspect :ets.lookup(:user_table, userID)
        {:reply, userID, state}
    end

    @doc """
    Assuming the user is registered, so there is no need to check if the user exists in user_table
    """
    def handle_cast({:send_tweet, tweet, userID}, state) do        
        user_tuple = :ets.lookup(:user_table, userID) |> List.first
        :ets.insert(:user_table, {userID, elem(user_tuple, 1), elem(user_tuple, 2), [tweet | elem(user_tuple, 3)]})
        
        # prepend the tweet to each follower's tweets list
        send_to_followers(tweet, elem(user_tuple, 1), length(elem(user_tuple, 1)))
        case tweet_type(tweet) do
            {:hash_tag, tag} ->
                IO.puts "The hashtag is " <> tag             
                :ets.insert(:hash_tag_table, {tag, tweet})
                IO.puts "The hashtag table now is " 
                IO.inspect :ets.lookup(:hash_tag_table, tag)                
            {:mention, mention} ->
                IO.puts "The mention is " <> mention                             
                :ets.insert(:mention_table, {mention, tweet})   
                IO.puts "The mention table now is " 
                IO.inspect :ets.lookup(:mention_table, mention) 
            :plain_tweet ->
                IO.puts "This is a normal tweet"                            
        end
        
        IO.puts "The updated user_table after inserting tweet for userID is " 
        IO.inspect :ets.lookup(:user_table, userID)

        {:noreply, state}
    end

    @doc """
    If user A subscribe to user B, add A to B's followers list and add B to A's following list
    """
    def handle_call({:subscribe, to_subscribe_ID, userID}, _from, state) do
        user_tuple = :ets.lookup(:user_table, userID) |> List.first
        case user_status(to_subscribe_ID) do
            :ok ->
                following_tuple = :ets.lookup(:user_table, to_subscribe_ID) |> List.first
                :ets.insert(:user_table, {userID, elem(user_tuple, 1), [to_subscribe_ID | elem(user_tuple, 2)], elem(user_tuple, 3)})
                :ets.insert(:user_table, {to_subscribe_ID, [userID | elem(following_tuple, 1)], elem(following_tuple, 2), elem(following_tuple, 3)})             
            :error ->
                IO.puts "Sorry, the user you are subscribing to does not exist."
        end
        IO.puts "The updated user_table for userID after subscribing is " 
        IO.inspect :ets.lookup(:user_table, userID)

        IO.puts "The updated user_table for followingID after subscribing is " 
        IO.inspect :ets.lookup(:user_table, to_subscribe_ID)
        # TO IMPLEMENT ====> need to push to_subscribe_ID's tweets to userID  
        {:reply, userID, state}
    end
    
    def handle_call({:query_tweet, query, userID}, _from, state) do
        user_tuple = :ets.lookup(:user_table, userID) |> List.first
        result =
            case query_type(query) do
                :subscribtion ->
                    elem(user_tuple, 3)
                {:hash_tag, hash_tag} ->
                    list1 = :ets.lookup(:hash_tag_table, hash_tag)
                    form_list(list1, [], length(list1))  
                {:mention, mention} ->
                    list2 = :ets.lookup(:mention_table, mention)
                    form_list(list2, [], length(list2))       
            end
        {:reply, result, state}
    end
    ######################### helper functions ####################

    defp user_status(userID) do
        case :ets.lookup(:user_table, userID) do              
            [{^userID, _, _, _}] -> 
                :ok
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

    defp send_to_followers(tweet, followers_list, count) when count > 0 do     
        follower = List.first(followers_list)

        # delete from the front of the list
        followers_list = List.delete_at(followers_list, 0) 

        # list of tuple of the form: {follower, [], [], []}
        follower_tuple = :ets.lookup(:user_table, follower) |> List.first 
        
        # get follower's tweet list then prepend tweet to the list
        :ets.insert(:user_table, {follower, elem(follower_tuple, 1), elem(follower_tuple, 2), [tweet | elem(follower_tuple, 3)]})
        # recursively process the next follower
        send_to_followers(tweet, followers_list, count - 1)
    end
    
    defp send_to_followers(tweet, followers_list, count) do
        :ok
    end

    # this will match tweet of hashtag or mention type, with # comes first
    # so if a tweet is "this is a test #@hi tweet", it is matched as hashtag tweet
    defp tweet_type(tweet) do
        result = 
            cond do
                tweet =~ "#" ->
                    hash_tag = 
                    String.split(tweet, ~r{#}, parts: 2) # regular expression to match # and split with that
                    |> List.last
                    |> String.split(~r{\s}, trim: true)
                    |> List.first
                    {:hash_tag, hash_tag}
                tweet =~ "@" ->
                    mention = 
                    String.split(tweet, ~r{@}, parts: 2) # regular expression to match @ and split with that
                    |> List.last
                    |> String.split(~r{\s}, trim: true)
                    |> List.first
                    {:mention, mention}
                true ->
                    :plain_tweet
            end
        #result
    end


    defp query_type(query) do
        result = 
            cond do
                String.contains?(query, "#") ->
                    {:hash_tag, String.slice(query, 1..(String.length(query) - 1))}
                String.contains?(query, "@") ->
                    {:mention, String.slice(query, 1..(String.length(query) - 1))}
                true ->
                    :subscribtion
            end  
    end

    @doc """
    defp query_type(query) do
        result = [:subscribtion]
        if String.contains?(query, "#") do
            result = [:hash_tag | result]
        end
        if String.contains?(query, "#") do
            result = [:mention | result]            
        end
        result
    end
    """

    # change [{"h", "hi"}, {"h", "hello"}, {"h", "how"}] to ["hi", "hello", "how"]
    defp form_list(tuple_list, result_list, count)  when count > 0 do
        tweet = tuple_list 
                |>List.first 
                |> elem(1)
        result_list = [tweet | result_list]
        tuple_list = List.delete_at(tuple_list, 0)
        form_list(tuple_list, result_list, count - 1)
    end

    defp form_list(tuple_list, result_list, count) do
        result_list
    end
 end