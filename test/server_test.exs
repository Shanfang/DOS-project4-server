defmodule ServerTest do
  use ExUnit.Case
  doctest Server

  setup do
    {:ok,server_pid} = Server.start_link
    {:ok,server: server_pid}
  end

  test "register account1" do
    assert Server.register_account("shanfang") == "shanfang"
  end

  test "register account2" do
    assert Server.register_account("dobra") == "dobra"
  end

  test "register account3" do
    assert Server.register_account("twitter") == "twitter"
  end

  test "dobra subscribe to shanfang" do
    assert Server.subscribe("shanfang", "dobra") == "dobra"
  end

  test "twitter subscribe to shanfang" do
    assert Server.subscribe("shanfang", "twitter") == "twitter"
  end

  test "dobra subscribe to twitter" do
    assert Server.subscribe("twitter", "dobra") == "dobra"
  end

  test "twitter subscribe to dobra" do
    assert Server.subscribe("dobra", "twitter") == "twitter"
  end

  test "shanfang sends a plain tweet" do
    assert Server.send_tweet("Twitter engine is cool!", "shanfang") == :ok
  end

  test "shanfang sends a hashtag tweet" do
    assert Server.send_tweet("We are celebrating #thanksgiving by coding all day!", "shanfang") == :ok
  end

  test "shanfang sends a mention tweet" do
    assert Server.send_tweet("Dr. @dobra, could you please make the description more clear?", "shanfang") == :ok
  end

  test "dobra checks his timeline by mention" do
    assert :ets.lookup(:mention_table, "dobra") == ["Dr. @dobra, could you please make the description more clear?"]
    assert Server.query_tweet("@dobra", "dobra") == ["Dr. @dobra, could you please make the description more clear?"]
  end
  
end
