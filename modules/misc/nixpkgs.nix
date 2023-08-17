{ config, pkgs, lib, pkgsPath, ... }:

with lib;

let
  cfg = config.nixpkgs;
  isConfig = x: builtins.isAttrs x || isFunction x;

  optCall = f: x: if isFunction f then f x else f;

  mergeConfig = lhs_: rhs_:
    let
      lhs = optCall lhs_ { inherit pkgs; };
      rhs = optCall rhs_ { inherit pkgs; };
    in recursiveUpdate lhs rhs // optionalAttrs (lhs ? packageOverrides) {
      packageOverrides = pkgs:
        optCall lhs.packageOverrides pkgs
        // optCall (attrByPath [ "packageOverrides" ] { } rhs) pkgs;
    } // optionalAttrs (lhs ? perlPackageOverrides) {
      perlPackageOverrides = pkgs:
        optCall lhs.perlPackageOverrides pkgs
        // optCall (attrByPath [ "perlPackageOverrides" ] { } rhs) pkgs;
    };

  configType = mkOptionType {
    name = "nixpkgs-config";
    description = "nixpkgs config";
    check = x:
      let traceXIfNot = c: if c x then true else traceSeqN 1 x false;
      in traceXIfNot isConfig;
    merge = _: foldr (def: mergeConfig def.value) { };
  };

  overlayType = mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = isFunction;
    merge = mergeOneOption;
  };

  defaultPkgs = import pkgsPath {
    config = if cfg.config != null then cfg.config else { };

    overlays = if cfg.overlays != null then cfg.overlays else [ ];

    localSystem.system = cfg.system;
  };

in {
  options.nixpkgs = {
    config = mkOption {
      default = null;
      example = { allowBroken = true; };
      type = types.nullOr configType;
      description = ''
        The configuration of the Nix Packages collection. (For
        details, see the Nixpkgs documentation.) It allows you to set
        package configuration options.

        If `null`, then configuration is taken from
        the fallback location, for example,
        {file}`~/.config/nixpkgs/config.nix`.

        Note, this option will not apply outside your Home Manager
        configuration like when installing manually through
        {command}`nix-env`. If you want to apply it both
        inside and outside Home Manager you can put it in a separate
        file and include something like

        ```nix
          nixpkgs.config = import ./nixpkgs-config.nix;
          xdg.configFile."nixpkgs/config.nix".source = ./nixpkgs-config.nix;
        ```

        in your Home Manager configuration.
      '';
    };

    overlays = mkOption {
      default = null;
      example = literalExpression ''
        [
          (final: prev: {
            openssh = prev.openssh.override {
              hpnSupport = true;
              withKerberos = true;
              kerberos = final.libkrb5;
            };
          })
        ]
      '';
      type = types.nullOr (types.listOf overlayType);
      description = ''
        List of overlays to use with the Nix Packages collection. (For
        details, see the Nixpkgs documentation.) It allows you to
        override packages globally. This is a function that takes as
        an argument the *original* Nixpkgs. The
        first argument should be used for finding dependencies, and
        the second should be used for overriding recipes.

        If `null`, then the overlays are taken from
        the fallback location, for example,
        {file}`~/.config/nixpkgs/overlays`.

        Like {var}`nixpkgs.config` this option only
        applies within the Home Manager configuration. See
        {var}`nixpkgs.config` for a suggested setup that
        works both internally and externally.
      '';
    };

    system = mkOption {
      type = types.str;
      example = "i686-linux";
      description = ''
        Specifies the Nix platform type for which the user environment
        should be built. If unset, it defaults to the platform type of
        your host system. Specifying this option is useful when doing
        distributed multi-platform deployment, or when building
        virtual machines.
      '';
    };
  };

  config = {
    nixpkgs = lib.mkIf (!lib.inPureEvalMode) {
      system = lib.mkDefault builtins.currentSystem;
    };
    _module.args.pkgs = lib.mkOverride lib.modules.defaultOverridePriority
      defaultPkgs.__splicedPackages;
  };
}
