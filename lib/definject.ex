defmodule Definject do
  @doc """
  `definject` transforms a function to accept a map where dependent functions can be injected.

      import Definject

      definject send_welcome_email(user_id) do
        %{email: email} = Repo.get(User, user_id)

        welcome_email(to: email)
        |> Mailer.send()
      end

  is expanded into

      def send_welcome_email(user_id, deps \\\\ %{}) do
        %{email: email} = (deps[&Repo.get/2] || &Repo.get/2).(User, user_id)

        welcome_email(to: email)
        |> (deps[&Mailer.send/1] || &Mailer.send/1).()
      end

  Note that local function calls like `welcome_email(to: email)` are not expanded unless it is prepended with `__MODULE__`.

  Now, you can inject mock functions in tests.

      test "send_welcome_email" do
        Accounts.send_welcome_email(100, %{
          &Repo.get/2 => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
          &Mailer.send/1 => fn %Email{to: "mr.jechol@gmail.com", subject: "Welcome"} ->
            Process.send(self(), :email_sent)
          end
        })

        assert_receive :email_sent
      end

  `definject` raises if the passed map includes a function that's not called within the injected function.
  You can disable this by adding `strict: false` option.

      test "send_welcome_email with strict: false" do
        Accounts.send_welcome_email(100, %{
          &Repo.get/2 => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
          &Repo.all/1 => fn _ -> [%User{email: "mr.jechol@gmail.com"}] end, # Unused
          strict: false,
        })
      end
  """
  defmacro definject(head, do: body) do
    alias Definject.Inject

    original =
      quote do
        def unquote(head), do: unquote(body)
      end

    if Application.get_env(:definject, :enable, Mix.env() == :test) do
      injected = Inject.inject_function(head, body, __CALLER__)

      if Application.get_env(:definject, :trace, false) do
        %{file: file, line: line} = __CALLER__

        IO.puts("definject converting #{file}:#{line}")
        IO.puts("Before >>>")
        IO.puts(original |> Macro.to_string())
        IO.puts("After >>>")
        IO.puts(injected |> Macro.to_string())
      end

      injected
    else
      original
    end
  end

  @doc """
  If you don't need pattern matching in mock function, `mock/1` can be used to reduce boilerplates.

      test "send_welcome_email with mock/1" do
        Accounts.send_welcome_email(
          100,
          mock(%{
            &Repo.get/2 => %User{email: "mr.jechol@gmail.com"},
            &Mailer.send/1 => Process.send(self(), :email_sent)
          })
        )

        assert_receive :email_sent
      end

  Note that `Process.send(self(), :email_sent)` is surrounded by `fn _ -> end` when expanded.
  """
  defmacro mock({:%{}, context, mocks}) do
    alias Definject.Mock

    {:%{}, context, mocks |> Enum.map(&Mock.decorate_with_fn/1)}
  end
end
