{ pkgsPath, lib, check ? true, readonlyPkgs ? false, pkgs ? null }:

let
  baseModules = (import ./module-list.nix) ++ [
    ("${pkgsPath}/nixos/modules/misc/assertions.nix")
    ("${pkgsPath}/nixos/modules/misc/meta.nix")
  ] ++ lib.optional (!readonlyPkgs) ./misc/nixpkgs.nix
    ++ lib.optional (readonlyPkgs) ./misc/nixpkgs-readonly.nix;

in baseModules ++ [{
  _module = {
    inherit check;
    args = {
      inherit baseModules pkgsPath;
      modulesPath = toString ./.;
    };
  };
  #This also checks to make sure lib is set correctly
  lib = lib.hm;
  nixpkgs.pkgs = lib.mkIf readonlyPkgs (lib.mkDefault pkgs);
}]
