# DefInject
Functional Dependency Injection in Elixir

## Installation

The package can be installed by adding `definject` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [{:definject, "~> 0.1.0", only: :test}]
end
```

## Features

### `definject`

`definject` transforms function to accept a map where we can inject dependent functions.

```elixir
use Inject

definject send_welcome_email(user_id) do
  %{email: email} = Repo.get(User, user_id)

  Email.welcome(email)
  |> Mailer.send()
end
```

becomes

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
If you are not interested in parameters of mock function, `mock/1` is handy to reduce boilerplates.

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

Note that `Process.send(self(), :email_sent)` is surrounded by `fn _ -> end`.

### `strict: false`

`definject` raises if the passed map includes function which is not dependency of the injected function.
You can disable this check by adding strict: false.

```elixir
test "send_welcome_email with strict: false" do
  Accounts.send_welcome_email(100, %{
    {Repo, :get, 2} => fn User, 100 -> %User{email: "mr.jechol@gmail.com"} end,
    {Repo, :all, 1} => fn _ -> [%User{email: "mr.jechol@gmail.com"}] end,
    :strict => false,
  })
end
```

## Why?

1. As we inject objects via constructor in OOP, we should inject functions via arguments in FP.
2. Mocking per function is better than mocking per module as we need only subset of module for single test.
3. Unlike other mocking libraries which modifies global modules and disables async tests, 
  definject does not modify global modules so enables async tests.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details