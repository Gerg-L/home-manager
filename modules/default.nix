{
  modules,
  nixpkgs ? null,
  pkgs ? null,
  # Whether to check that each option has a matching declaration.
  check ? true,
  # Extra arguments passed to specialArgs.
  extraSpecialArgs ? {},
}: let
  nixpkgsIsNull = nixpkgs == null;
  nixpkgsIsFlake = (nixpkgs._type or "") == "flake";
  pkgsIsNull = pkgs == null;
  pkgsIsPkgs = (pkgs._type or "") == "pkgs";

  pkgsPath =
    if (! pkgsIsNull)
    then
      if pkgsIsPkgs
      then pkgs.path
      else toString pkgs
    else if (! nixpkgsIsNull)
    then
      if nixpkgsIsFlake
      then nixpkgs.outPath
      else toString nixpkgs
    else if (builtins ? currentSystem)
    then <nixpkgs>
    else
      throw ''
        Neither nixpkgs or pkgs is passed to modules/default.nix
      '';

  lib = import ./lib/stdlib-extended.nix (
    if (! pkgsIsNull)
    then
      if pkgsIsPkgs
      then pkgs.lib
      else import ((toString pkgs) + /lib)
    else if (! nixpkgsIsNull)
    then
      if nixpkgsIsFlake
      then nixpkgs.lib
      else import ((toString nixpkgs) + /lib)
    else if (builtins ? currentSystem)
    then import <nixpkgs/lib>
    else
      throw ''
        Neither nixpkgs or pkgs is passed to modules/default.nix
      ''
  );

  readOnlyPkgs = if (! pkgsIsNull)
  then
    if pkgsIsPkgs
    then true
    else lib.warn ''
      The pkgs passed to modules/default.nix is not of type "pkgs"
      It will be ignored
    '' false
  else false;

  collectFailed = cfg:
    map (x: x.message) (lib.filter (x: !x.assertion) cfg.assertions);

  showWarnings = res: let
    f = w: builtins.trace "[1;31mwarning: ${w}[0m";
  in
    lib.fold f res res.config.warnings;

  hmModules = import ./all-modules.nix {
    inherit check lib pkgsPath pkgs readOnlyPkgs;
  };

  #This use of lib passes lib to all modules
  rawModule = lib.evalModules {
    specialArgs = extraSpecialArgs;
    modules = modules ++ hmModules;
  };

  module = showWarnings (let
    failed = collectFailed rawModule.config;
    failedStr = lib.concatStringsSep "\n" (map (x: "- ${x}") failed);
  in
    if failed == []
    then rawModule
    else
      throw ''

        Failed assertions:
        ${failedStr}'');
in {
  inherit (module) options config;

  inherit (module.config.home) activationPackage;

  # For backwards compatibility. Please use activationPackage instead.
  activation-script = module.config.home.activationPackage;

  newsDisplay = rawModule.config.news.display;
  newsEntries =
    lib.sort (a: b: a.time > b.time)
    (lib.filter (a: a.condition) rawModule.config.news.entries);

  #inherit (module._module.args) pkgs;
}
