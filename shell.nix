let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  jechol-nur = import sources.jechol-nur { };
  inherit (pkgs.lib) optional optionals;
in pkgs.mkShell {
  buildInputs = [
    # pkgs.beam.interpreters.erlangR23
    # pkgs.beam.packages.erlangR23.elixir_1_9
    jechol-nur.beam.main.packages.erlang_23_0.elixirs.elixir_1_9_0
  ];
}
