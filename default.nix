{ pkgs ? null }:
let
  pkgs_ = if pkgs == null then import <nixpkgs> { } else pkgs;
  pkgsPath = pkgs_.path;
in rec {
  docs = let releaseInfo = pkgs.lib.importJSON ./release.json;
  in with import ./docs {
    inherit pkgsPath;
    pkgs = pkgs_;
    lib = import ./modules/lib/stdlib-extended.nix pkgs_.lib;
    inherit (releaseInfo) release isReleaseBranch;
  }; {
    html = manual.html;
    manPages = manPages;
    json = options.json;
    jsonModuleMaintainers = jsonModuleMaintainers; # Unstable, mainly for CI.
  };

  home-manager = pkgs_.callPackage ./home-manager {
    inherit pkgsPath;
    path = toString ./.;
  };

  install =
    pkgs_.callPackage ./home-manager/install.nix { inherit home-manager; };

  nixos = import ./nixos;

  path = ./.;
}
