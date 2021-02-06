defmodule HeavyKeeper do
  @decay_probability 1.08

  defstruct buckets: [], depth: 0, width: 0

  @type t :: %__MODULE__{
          buckets: list(:atomics.atomics_ref()),
          depth: pos_integer(),
          width: pos_integer()
        }

  @spec new(non_neg_integer(), non_neg_integer()) :: t
  def new(width, depth) do
    buckets = for _ <- 1..depth, do: :atomics.new(width * 2, [{:signed, false}])

    %__MODULE__{
      buckets: buckets,
      width: width,
      depth: depth
    }
  end

  @spec add(t, any()) :: non_neg_integer()
  def add(keeper, key) do
    keeper.buckets
    |> Enum.with_index()
    |> Enum.map(&update(&1, key, keeper.width))
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> 0
      list -> Enum.max(list)
    end
  end

  @spec lookup(t, any()) :: non_neg_integer()
  def lookup(keeper, key) do
    fingerprint = :erlang.phash2(key)

    keeper.buckets
    |> Enum.with_index()
    |> Enum.flat_map(fn {atomic, idx} ->
      bucket = bucket(key, idx, keeper.width)

      case {:atomics.get(atomic, bucket), :atomics.get(atomic, bucket + 1)} do
        {^fingerprint, count} -> [count]
        {_fingerprint, _} -> []
      end
    end)
    |> case do
      [] -> 0
      list -> Enum.max(list)
    end
  end

  @spec update({:atomics.atomics_ref(), non_neg_integer()}, any(), non_neg_integer()) :: nil | non_neg_integer()
  def update({atomic, idx}, key, width) do
    fingerprint = :erlang.phash2(key)
    bucket = bucket(key, idx, width)

    case {:atomics.get(atomic, bucket), :atomics.get(atomic, bucket + 1)} do
      {0, 0} ->
        :atomics.put(atomic, bucket, fingerprint)
        :atomics.put(atomic, bucket + 1, 1)
        1

      {^fingerprint, _count} ->
        :atomics.add_get(atomic, bucket + 1, 1)

      {_fingerprint, count} ->
        r = :rand.uniform()
        prob = :math.pow(@decay_probability, -1 * count)

        case r < prob do
          true ->
            case count - 1 do
              0 ->
                :atomics.put(atomic, bucket, fingerprint)
                :atomics.put(atomic, bucket + 1, 1)
                1

              _ ->
                :atomics.sub_get(atomic, bucket + 1, 1)
                nil
            end

          false ->
            nil
        end
    end
  end

  @spec bucket(any(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  defp bucket(key, seed, width) do
    rem(Murmur.hash_x86_128(key, seed), width) * 2 + 1
  end
end
