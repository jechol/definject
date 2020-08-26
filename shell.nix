let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  inherit (pkgs.lib) optional optionals;
in
pkgs.mkShell {
  buildInputs = [
    pkgs.beam.interpreters.erlangR23
    pkgs.beam.packages.erlangR23.elixir_1_10
  ];
}
