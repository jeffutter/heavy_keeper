defmodule HeavyKeeperTest do
  use ExUnit.Case
  doctest HeavyKeeper

  use PropCheck
  use PropCheck.StateM.ModelDSL

  test "adds keys to the data structure" do
    keeper = HeavyKeeper.new(1000, 4)

    HeavyKeeper.add(keeper, :a)
    HeavyKeeper.add(keeper, :a)
    HeavyKeeper.add(keeper, :a)
    HeavyKeeper.add(keeper, :a)
    HeavyKeeper.add(keeper, :a)

    assert HeavyKeeper.lookup(keeper, :a) == 5
  end

  property "stateful property", [:verbose, numtests: 500, max_size: 250] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        r = run_commands(__MODULE__, cmds)
        {_history, _state, result} = r

        (result == :ok)
        |> when_fail(print_report(r, cmds))
      end
    end
  end

  def initial_state, do: %{heavy_keeper: nil, model: %{}}

  def command_gen(%{heavy_keeper: nil}) do
    {:create_heavy_keeper, []}
  end

  def command_gen(%{heavy_keeper: heavy_keeper, model: model}) when model == %{} do
    {:add, [heavy_keeper, utf8()]}
  end

  def command_gen(%{heavy_keeper: heavy_keeper, model: model}) do
    known_key =
      model
      |> Map.keys()
      |> Enum.take_random(1)
      |> List.first()

    key = weighted_union([{4, known_key}, {1, utf8()}])

    frequency([
      {4, {:add, [heavy_keeper, key]}},
      {1, {:lookup, [heavy_keeper, key]}}
    ])
  end

  defcommand :create_heavy_keeper do
    def impl() do
      HeavyKeeper.new(1000, 4)
    end

    def next(state, _args, heavy_keeper) do
      %{state | heavy_keeper: heavy_keeper}
    end
  end

  defcommand :add do
    def impl(heavy_keeper, key) do
      HeavyKeeper.add(heavy_keeper, key)
    end

    def post(state, [_heavy_keeper, key], result) do
      Map.get(state.model, key, 0) + 1 == result
    end

    def next(state, [_heavy_keeper, key], _result) do
      model = Map.update(state.model, key, 1, fn v -> v + 1 end)
      %{state | model: model}
    end
  end

  defcommand :lookup do
    def impl(heavy_keeper, key) do
      HeavyKeeper.lookup(heavy_keeper, key)
    end

    def post(state, [_heavy_keeper, key], result) do
      Map.get(state.model, key, 0) == result
    end
  end
end
