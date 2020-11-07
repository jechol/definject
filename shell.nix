let
  nixpkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/20.09.tar.gz";
    sha256 = "1wg61h4gndm3vcprdcg7rc4s1v3jkm5xd7lw8r2f67w502y94gcy";
  }) { };
  beam = import (fetchTarball {
    url = "https://github.com/jechol/nix-beam/archive/v4.3.tar.gz";
    sha256 = "117c43s256i2nzp0zps9n2f630gm00yhsbgc78r2qimi0scdxf52";
  }) { };
in nixpkgs.mkShell {
  buildInputs = [
    beam.erlang.v23_1
    beam.pkg.v23_1.elixir.v1_11_0
  ];
}
