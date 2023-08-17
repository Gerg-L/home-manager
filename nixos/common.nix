# This module is the common base for the NixOS and nix-darwin modules.
# For OS-specific configuration, please edit nixos/default.nix or nix-darwin/default.nix instead.

{ config, options, pkgs, lib, ... }:

let

  opt = options.home-manager;
  cfg = config.home-manager;

  pkgsOr = if opt.customPkgs.isDefined then cfg.customPkgs else pkgs;
  #pkgsOr = pkgs;

  hmModule = lib.types.submoduleWith {
    description = "Home Manager module";

    specialArgs = let
      attrs = [ "config" "pkgs" "lib" "modulesPath" ];
      usedSpecialArgs =
        builtins.filter (n: (cfg.extraSpecialArgs.${n} or null) != null) attrs;
      warnSpecialArgs = v:
        lib.warnIf (usedSpecialArgs != [ ]) ''
          passing config, pkgs, lib, or modulesPath is being passed to extraSpecialArgs
          these attributes will be ignored as they are potentially harmful
        '' v;
      filteredSpecialArgs = v: warnSpecialArgs (removeAttrs v attrs);

    in (filteredSpecialArgs cfg.extraSpecialArgs) // {
      lib = import ../modules/lib/stdlib-extended.nix pkgsOr.lib;
      osConfig = config;
    };
    modules = (import ../modules/all-modules.nix ({
      #this is fine here because pkgs is already instantiated
      pkgsPath = pkgsOr.path;
      pkgs = pkgsOr;
      readonlyPkgs = true;
      lib = import ../modules/lib/stdlib-extended.nix pkgsOr.lib;
    })) ++ [

      ({ name, ... }: {
        submoduleSupport.enable = true;
        submoduleSupport.externalPackageInstall = cfg.useUserPackages;

        home.username = config.users.users.${name}.name;
        home.homeDirectory = config.users.users.${name}.home;

        # Make activation script use same version of Nix as system as a whole.
        # This avoids problems with Nix not being in PATH.
        nix.package = config.nix.package;
      })
    ] ++ cfg.sharedModules;
  };

in with lib; {
  options.home-manager = {

    useUserPackages = mkEnableOption ''
      installation of user packages through the
      {option}`users.users.<name>.packages` option'';

    customPkgs = mkOption {
      type = types.pkgs;
      example = ''
        import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; }'';
      description = ''
        Set the `pkgs` module argument to a already instantiated nixpkgs
      '';
    };

    backupFileExtension = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "backup";
      description = ''
        On activation move existing files by appending the given
        file extension rather than exiting with an error.
      '';
    };

    extraSpecialArgs = mkOption {
      type = types.attrs;
      default = { };
      example = literalExpression "{ inherit emacs-overlay; }";
      description = ''
        Extra `specialArgs` passed to Home Manager. This
        option can be used to pass additional arguments to all modules.
      '';
    };

    sharedModules = mkOption {
      type = with types; listOf raw;
      default = [ ];
      example = literalExpression "[ { home.packages = [ nixpkgs-fmt ]; } ]";
      description = ''
        Extra modules added to all users.
      '';
    };

    verbose = mkEnableOption "verbose output on activation";

    users = mkOption {
      type = types.attrsOf hmModule;
      default = { };
      # Prevent the entire submodule being included in the documentation.
      visible = "shallow";
      description = ''
        Per-user Home Manager configuration.
      '';
    };
  };

  config = mkIf (cfg.users != { }) {
    warnings = flatten (flip mapAttrsToList cfg.users (user: config:
      flip map config.warnings (warning: "${user} profile: ${warning}")));

    assertions = flatten (flip mapAttrsToList cfg.users (user: config:
      flip map config.assertions (assertion: {
        inherit (assertion) assertion;
        message = "${user} profile: ${assertion.message}";
      })));

    users.users = mkIf cfg.useUserPackages
      (mapAttrs (username: usercfg: { packages = [ usercfg.home.path ]; })
        cfg.users);

    environment.pathsToLink = mkIf cfg.useUserPackages [ "/etc/profile.d" ];
  };
}

