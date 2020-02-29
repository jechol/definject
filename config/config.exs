use Mix.Config

if Mix.env() == :test do
  config :definject, :uninjectable, [DoNotInject]
end
