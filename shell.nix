let
  nixpkgs = import (fetchTarball {
    url = "https://github.com/trevorite/nixpkgs/archive/21.05.tar.gz";
    sha256 = "sha256:1ckzhh24mgz6jd1xhfgx0i9mijk6xjqxwsshnvq789xsavrmsc36";
  }) { };
  platform = if nixpkgs.stdenv.isDarwin then [
    nixpkgs.darwin.apple_sdk.frameworks.CoreServices
    nixpkgs.darwin.apple_sdk.frameworks.Foundation
  ] else if nixpkgs.stdenv.isLinux then
    [ nixpkgs.inotify-tools ]
  else
    [ ];
in nixpkgs.mkShell {
  buildInputs = [ nixpkgs.erlang nixpkgs.elixir ] ++ platform;
}
