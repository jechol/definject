defmodule Definject.TryTest do
  use ExUnit.Case, async: true
  import Definject

  def foo(_arg) do
    raise RuntimeError, "foo/1 is not supposed to be called."
  end

  defmodule Try do
    alias Definject.TryTest

    definject execute(command, receiver) do
      case command do
        :rescue -> raise RuntimeError, "rescue!"
        :catch -> throw({:ok, :catch})
        :else -> {:ok, :else}
      end
    rescue
      _e in RuntimeError ->
        TryTest.foo(:rescue)
        {:ok, :rescue}
    catch
      {:ok, :catch} ->
        TryTest.foo(:catch)
        {:ok, :catch}
    else
      {:ok, :else} ->
        TryTest.foo(:else)
        {:ok, :else}
    after
      send(receiver, TryTest.foo(:after))
      :this_value_doesnt_matter
    end
  end

  test "rescue" do
    rescue_ref = make_ref()
    after_ref = make_ref()

    assert Try.execute(:rescue, self(), %{
             &__MODULE__.foo/1 => fn
               :rescue -> send(self(), {:rescue, rescue_ref})
               :after -> send(self(), {:after, after_ref})
             end
           }) == {:ok, :rescue}

    assert_receive {:rescue, ^rescue_ref}
    assert_receive {:after, ^after_ref}
  end

  test "catch" do
    catch_ref = make_ref()
    after_ref = make_ref()

    assert Try.execute(:catch, self(), %{
             &__MODULE__.foo/1 => fn
               :catch -> send(self(), {:catch, catch_ref})
               :after -> send(self(), {:after, after_ref})
             end
           }) == {:ok, :catch}

    assert_receive {:catch, ^catch_ref}
    assert_receive {:after, ^after_ref}
  end

  test "else" do
    else_ref = make_ref()
    after_ref = make_ref()

    assert Try.execute(:else, self(), %{
             &__MODULE__.foo/1 => fn
               :else -> send(self(), {:else, else_ref})
               :after -> send(self(), {:after, after_ref})
             end
           }) == {:ok, :else}

    assert_receive {:else, ^else_ref}
    assert_receive {:after, ^after_ref}
  end
end
