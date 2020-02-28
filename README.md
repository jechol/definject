# DefInject
Functional Dependency Injection in Elixir

## Why?
Existing mock libraries provide mocks at module level. While this approach works okay, it is somewhat rigid and cumbersome to use. Besides, functions are the basic building blocks of functional programming, not modules. Wouldn't it be nice to have a way to inject mocks at function level then?

`definject` is an alternative way to inject mocks to each function. It grants a more fine-grained control over mocks, allowing you to provide different mocks to each function. It also does not limit using `:async` option as mocks are contained in each test function.

## Installation

The package can be installed by adding `definject` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [{:definject, "~> 0.1.0"}]
end
```

## Usage

### `definject`

`definject` transforms a function to accept a map where dependent functions can be injected.

```elixir
use Inject

definject send_welcome_email(user_id) do
  %{email: email} = Repo.get(User, user_id)

  Email.welcome(email)
  |> Mailer.send()
end
```

is expanded into

```elixir
def send_welcome_email(user_id, deps \\ %{}) do
  %{email: email} = (deps[{Repo, :get, 2}] || &Repo.get/2).(User, user_id)

  (deps[{Email, :welcome, 1}] || &Email.welcome/1).(email)
  |> (deps[{Mailer, :send, 1}] || &Mailer.send/1).()
end
```

Then we can inject mock functions in tests.

```elixir
test "send_welcome_email" do
  Accounts.send_welcome_email(100, %{
    {Repo, :get, 2} => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
    {Mailer, :send, 1} => fn %Email{to: "mr.jechol@gmail.com", subject: "Welcome"} ->
      Process.send(self(), :email_sent)
    end
  })

  assert_receive :email_sent
end
```

### `mock`
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

### `strict: false`

`definject` raises if the passed map includes a function that's not called within the injected function.
You can disable this by adding `strict: false` option.

```elixir
test "send_welcome_email with strict: false" do
  Accounts.send_welcome_email(100, %{
    {Repo, :get, 2} => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
    {Repo, :all, 1} => fn _ -> [%User{email: "mr.jechol@gmail.com"}] end,
    :strict => false,
  })
end
```

## License	

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
