# Definject

[![Hex version badge](https://img.shields.io/hexpm/v/definject.svg)](https://hex.pm/packages/definject)
[![License badge](https://img.shields.io/hexpm/l/definject.svg)](https://github.com/chain-partners/definject/blob/master/LICENSE.txt)

Unobtrusive Dependency Injector for Elixir

## Why?

Let's say we want to test following function with mocks for `Repo` and `Mailer`.

```elixir
def send_welcome_email(user_id) do
  %{email: email} = Repo.get(User, user_id)

  welcome_email(to: email)
  |> Mailer.send()
end
```

Here's how you use one of the existing mock libraries:

```elixir
def send_welcome_email(user_id, repo \\ Repo, mailer \\ Mailer) do
  %{email: email} = repo.get(User, user_id)

  welcome_email(to: email)
  |> mailer.send()
end
```

First, I believe that this approach is too obtrusive as it requires modifying the function body to make it testable. Second, with `Repo` replaced with `repo`, the compiler can no longer guarantee the existence of `Repo.get/2` function.

`definject` does not require you to modify function arguments or body. Instead, you just need to replace `def` with `definject`. It also allows injecting different mocks to each function. It also does not limit using `:async` option as mocks are contained in each test function.

## Installation

The package can be installed by adding `definject` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [{:definject, "~> 0.5.1"}]
end
```

By default, `definject` is replaced with `def` in all but the test environment. Add the below configuration to enable in other environments.

```elixir
config :definject, :enable, true
```

## Usage

### definject

`definject` transforms a function to accept a map where dependent functions can be injected.

```elixir
import Definject

definject send_welcome_email(user_id) do
  %{email: email} = Repo.get(User, user_id)

  welcome_email(to: email)
  |> Mailer.send()
end
```

is expanded into

```elixir
def send_welcome_email(user_id, deps \\ %{}) do
  %{email: email} = (deps[&Repo.get/2] || &Repo.get/2).(User, user_id)

  welcome_email(to: email)
  |> (deps[&Mailer.send/1] || &Mailer.send/1).()
end
```

Note that local function calls like `welcome_email(to: email)` are not expanded unless it is prepended with `__MODULE__`.

Now, you can inject mock functions in tests.

```elixir
test "send_welcome_email" do
  Accounts.send_welcome_email(100, %{
    &Repo.get/2 => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
    &Mailer.send/1 => fn %Email{to: "mr.jechol@gmail.com", subject: "Welcome"} ->
      Process.send(self(), :email_sent)
    end
  })

  assert_receive :email_sent
end
```

`definject` raises if the passed map includes a function that's not called within the injected function.
You can disable this by adding `strict: false` option.

```elixir
test "send_welcome_email with strict: false" do
  Accounts.send_welcome_email(100, %{
    &Repo.get/2 => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
    &Repo.all/1 => fn _ -> [%User{email: "mr.jechol@gmail.com"}] end, # Unused
    strict: false,
  })
end
```

### mock

If you don't need pattern matching in mock function, `mock/1` can be used to reduce boilerplates.

```elixir
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
```

Note that `Process.send(self(), :email_sent)` is surrounded by `fn _ -> end` when expanded.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details
