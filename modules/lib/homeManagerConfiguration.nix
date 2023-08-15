lib: args:
let
  msgForRemovedArg = ''
    The 'homeManagerConfiguration' arguments

      - 'configuration',
      - 'username',
      - 'homeDirectory'
      - 'stateVersion',
      - 'extraModules', and
      - 'system'

    have been removed. Instead use the arguments 'pkgs' and
    'modules'. See the 22.11 release notes for more: https://nix-community.github.io/home-manager/release-notes.html#sec-release-22.11-highlights
  '';
  used = builtins.filter (n: (args.${n} or null) != null) [
    "configuration"
    "username"
    "homeDirectory"
    "stateVersion"
    "extraModules"
    "system"
  ];
  msg = msgForRemovedArg + ''
    Deprecated args passed:
  '' + builtins.concatStringsSep " " used;

  throwForRemovedArgs = v: lib.throwIf (used != [ ]) msg (v args);
in throwForRemovedArgs ({ modules ? [ ], nixpkgs ? null, extraSpecialArgs ? { }
  , check ? true, pkgs ? null, ... }:
  import ../. {

    inherit check modules pkgs nixpkgs;

    extraSpecialArgs = let
      attrs = [ "config" "pkgs" "lib" "modulesPath" ];
      usedSpecialArgs =
        builtins.filter (n: (extraSpecialArgs.${n} or null) != null) attrs;
      warnSpecialArgs = v:
        lib.warnIf (usedSpecialArgs != [ ]) ''
          passing config, pkgs, lib, or modulesPath is being passed to extraSpecialArgs
          these attributes will be ignored as they are potentially harmful
        '' v;
      filteredSpecialArgs = v: warnSpecialArgs (removeAttrs v attrs);

    in filteredSpecialArgs extraSpecialArgs;
  })
