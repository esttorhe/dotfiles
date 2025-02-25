{
  description = "Darwin configuration";

  nixConfig = {
    extra-trusted-substituters = ["https://cache.flox.dev"];
    extra-trusted-public-keys = ["flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="];
  };

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-24.11-darwin";
    nixpkgs-unstable.url = github:NixOS/nixpkgs/nixpkgs-unstable;

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin/nix-darwin-24.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    flox.url = "github:flox/flox/v1.3.0";

    mkAlias = {
      url = "github:reckenrode/mkAlias";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, darwin, flox, ... }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (inputs.nixpkgs-unstable.lib) attrValues makeOverridable optionalAttrs singleton;
      configuration = { pkgs, ... }: {
        environment.systemPackages =
          [
            inputs.flox.packages.${pkgs.system}.default
          ];

        nix.settings = {
          experimental-features = "nix-command flakes";
          substituters = [
            "https://cache.flox.dev"
          ];
          trusted-public-keys = [
            "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
          ];
        };
      };

    # Configuration for `nixpkgs`
    nixpkgsConfig = {
      config = { allowUnfree = true; };
      overlays = attrValues self.overlays ++ singleton (
        # Sub in x86 version of packages that don't build on Apple Silicon yet
        final: prev: (optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
          inherit (final.pkgs-x86)
            idris2
            #nix-index
            niv
            purescript;
        })
      );
    };
    in
    {
      #packages.aarch64-darwin.default' or 'defaultPackage.aarch64-darwin
      darwinConfigurations = {
        ZEN-V7LQFQX0L4 = darwinSystem {
        #"ZEN-XQQDXW76JN" = darwin.lib.darwinSystem {
        #"carbon" = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit inputs;
          };

          # Make inputs and system available to all modules.
          modules = attrValues self.darwinModules ++ [
            ./configuration.nix
            home-manager.darwinModules.home-manager
            {
              nixpkgs = nixpkgsConfig;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {inherit inputs;};
              home-manager.users."esteban.torres" = import ./home.nix; # { lib, ... }: import ./home.nix;
            }
          ];
        };
      };

      # Overlays --------------------------------------------------------------- {{{
      overlays = {
        # Overlay useful on Macs with Apple Silicon
          apple-silicon = final: prev: optionalAttrs (prev.stdenv.system == "aarch64-darwin") {
            # Add access to x86 packages system is running Apple Silicon
            pkgs-x86 = import inputs.nixpkgs-unstable {
              system = "x86_64-darwin";
              inherit (nixpkgsConfig) config;
            };
          }; 
        };

    # My `nix-darwin` modules that are pending upstream, or patched versions waiting on upstream
    # fixes.
    darwinModules = {
      security-pam = 
        # Upstream PR: https://github.com/LnL7/nix-darwin/pull/228
        { config, lib, pkgs, ... }:

        with lib;

        let
          cfg = config.security.pam;

          # Implementation Notes
          #
          # We don't use `environment.etc` because this would require that the user manually delete
          # `/etc/pam.d/sudo` which seems unwise given that applying the nix-darwin configuration requires
          # sudo. We also can't use `system.patchs` since it only runs once, and so won't patch in the
          # changes again after OS updates (which remove modifications to this file).
          #
          # As such, we resort to line addition/deletion in place using `sed`. We add a comment to the
          # added line that includes the name of the option, to make it easier to identify the line that
          # should be deleted when the option is disabled.
          mkSudoTouchIdAuthScript = isEnabled:
          let
            file   = "/etc/pam.d/sudo";
            option = "security.pam.enableSudoTouchIdAuth";
          in ''
            ${if isEnabled then ''
              # Enable sudo Touch ID authentication, if not already enabled
              if ! grep 'pam_tid.so' ${file} > /dev/null; then
                sed -i "" '2i\
              auth       sufficient     ${pkgs.pam-reattach}/lib/pam/pam_reattach.so # nix-darwin: ${option}
                ' ${file}
              fi
            '' else ''
              # Disable sudo Touch ID authentication, if added by nix-darwin
              if grep '${option}' ${file} > /dev/null; then
                sed -i "" '/${option}/d' ${file}
              fi
            ''}
          '';
        in

        {
          config = {
            system.activationScripts.extraActivation.text = ''
              # PAM settings
              echo >&2 "setting up pam..."
              ${mkSudoTouchIdAuthScript cfg.enableSudoTouchIdAuth}
            '';
          };
        };
      };
    };
}
