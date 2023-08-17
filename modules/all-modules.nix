{ pkgs ? null

, pkgsPath ? pkgs.path

, lib ? import ./lib/stdlib-extended.nix (pkgs.lib)

, check ? true

, readOnlyPkgs ? false }:

let
  baseModules = (import ./module-list.nix) ++ [
    ("${pkgsPath}/nixos/modules/misc/assertions.nix")
    ("${pkgsPath}/nixos/modules/misc/meta.nix")
  ] ++ lib.optional (!readOnlyPkgs) ./misc/nixpkgs.nix
    ++ lib.optional (readOnlyPkgs) ./misc/nixpkgs-readonly.nix;

in baseModules ++ [{
  _module = {
    inherit check;
    args = {
      inherit baseModules pkgsPath;
      modulesPath = toString ./.;
    };
  };
  #This will error if lib isn't properly extended
  lib = lib.hm;
  nixpkgs.pkgs = lib.mkIf readOnlyPkgs (lib.mkDefault pkgs);
}]
