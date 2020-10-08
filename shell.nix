let
  nixpkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/20.09-alpha.tar.gz";
    sha256 = "0dxrfr0w5ksvpjwz0d2hy7x7dirnc2xk9nw1np3wr6kvdlzhs3ik";
  }) { };
  jechol = import (fetchTarball {
    url = "https://github.com/jechol/nur-packages/archive/v2.5.tar.gz";
    sha256 = "08dgk1ha5spxwba4275hs22298z9z3l087cw1cdllhsp8r9h4vnh";
  }) { };
in nixpkgs.mkShell {
  buildInputs = [
    jechol.beam.main.erlangs.erlang_23_1
    jechol.beam.main.packages.erlang_23_1.elixirs.elixir_1_11_0
  ];
}
