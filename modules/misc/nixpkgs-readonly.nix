{ lib, config, ... }:

let
  cfg = config.nixpkgs;
  inherit (lib) mkOption types;

in {
  options = {
    nixpkgs = {
      pkgs = mkOption {
        type = types.unique { message = "nixpkgs.pkgs is et to read-only"; }
          lib.types.pkgs;
        description = lib.mdDoc "The pkgs module argument.";
      };
      config = mkOption {
        internal = true;
        type = types.unique { message = "nixpkgs.config is set to read-only"; }
          types.anything;
        description = lib.mdDoc ''
          The Nixpkgs `config` that `pkgs` was initialized with.
        '';
      };
      overlays = mkOption {
        internal = true;
        type =
          types.unique { message = "nixpkgs.overlays is set to read-only"; }
          types.anything;
        description = lib.mdDoc ''
          The Nixpkgs overlays that `pkgs` was initialized with.
        '';
      };
      system = mkOption {
        internal = true;
        readOnly = true;
        description = lib.mdDoc ''
          The system of the machine that is running the home-manager configuration.
        '';
      };
    };
  };
  config = {
    _module.args.pkgs = lib.mkForce (
      # find mistaken definitions
      builtins.seq cfg.config builtins.seq cfg.overlays cfg.pkgs);
    nixpkgs.config = cfg.pkgs.config;
    nixpkgs.overlays = cfg.pkgs.overlays;
    nixpkgs.system = cfg.pkgs.stdenv.hostPlatform;
  };
}
