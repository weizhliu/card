defmodule Card.RoomTest do
  use ExUnit.Case, async: false  # Not async because we use shared ETS tables
  alias Card.Room

  setup do
    # Clean up any test rooms after each test
    on_exit(fn ->
      # Try to delete test entries from ETS if they exist
      try do
        :ets.match_delete(:rooms, {:_, :_})
      rescue
        ArgumentError -> :ok
      end
    end)

    :ok
  end

  describe "new/1" do
    test "creates a room with auto-generated id" do
      room = Room.new()

      assert room.id != nil
      assert is_binary(room.id)
      assert room.host_ready == false
      assert room.guest_ready == false
      assert room.game == nil
      assert room.game_pid == nil
    end

    test "creates a room with custom attributes" do
      room = Room.new(%{host_ready: true})

      assert room.host_ready == true
      assert room.guest_ready == false
    end

    test "generates unique ids for different rooms" do
      room1 = Room.new()
      room2 = Room.new()

      assert room1.id != room2.id
    end

    test "stores room in ETS on creation" do
      room = Room.new()

      stored = Room.get(room.id)
      assert stored.id == room.id
    end
  end

  describe "get/1" do
    test "retrieves existing room" do
      room = Room.new()
      retrieved = Room.get(room.id)

      assert retrieved.id == room.id
      assert retrieved.host_ready == room.host_ready
      assert retrieved.guest_ready == room.guest_ready
    end

    test "returns nil for non-existent room" do
      result = Room.get("non_existent_id_12345")

      assert result == nil
    end
  end

  describe "update/2" do
    test "updates room in ETS" do
      room = Room.new()
      updated_room = %{room | host_ready: true}

      Room.update(room.id, updated_room)
      retrieved = Room.get(room.id)

      assert retrieved.host_ready == true
    end

    test "updates guest_ready status" do
      room = Room.new()
      updated_room = %{room | guest_ready: true}

      Room.update(room.id, updated_room)
      retrieved = Room.get(room.id)

      assert retrieved.guest_ready == true
    end

    test "updates both ready statuses" do
      room = Room.new()
      updated_room = %{room | host_ready: true, guest_ready: true}

      Room.update(room.id, updated_room)
      retrieved = Room.get(room.id)

      assert retrieved.host_ready == true
      assert retrieved.guest_ready == true
    end

    test "updates game reference" do
      room = Room.new()
      updated_room = %{room | game: "game_123"}

      Room.update(room.id, updated_room)
      retrieved = Room.get(room.id)

      assert retrieved.game == "game_123"
    end
  end

  describe "Room struct" do
    test "has expected fields" do
      room = %Room{}

      assert Map.has_key?(room, :id)
      assert Map.has_key?(room, :game)
      assert Map.has_key?(room, :game_pid)
      assert Map.has_key?(room, :host_ready)
      assert Map.has_key?(room, :guest_ready)
    end

    test "default values" do
      room = %Room{}

      assert room.id == nil
      assert room.game == nil
      assert room.game_pid == nil
      assert room.host_ready == false
      assert room.guest_ready == false
    end
  end

  describe "room lifecycle" do
    test "complete room lifecycle: create, update, retrieve" do
      # Create
      room = Room.new()
      assert room.host_ready == false
      assert room.guest_ready == false

      # Host joins and gets ready
      Room.update(room.id, %{room | host_ready: true})
      room = Room.get(room.id)
      assert room.host_ready == true
      assert room.guest_ready == false

      # Guest joins and gets ready
      Room.update(room.id, %{room | guest_ready: true})
      room = Room.get(room.id)
      assert room.host_ready == true
      assert room.guest_ready == true

      # Game starts, game reference is set
      Room.update(room.id, %{room | game: "game_abc", game_pid: self()})
      room = Room.get(room.id)
      assert room.game == "game_abc"
      assert room.game_pid == self()
    end
  end
end
