{
description = "drunkwhales' personal flake configuration";

inputs = {
  nixpkgs-6e99f2a2.url = "github:nixos/nixpkgs/6e99f2a27d600612004fbd2c3282d614bfee6421";
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager/release-25.11";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  disko.url = "github:nix-community/disko";
  disko.inputs.nixpkgs.follows = "nixpkgs";
  flake-utils.url = "github:numtide/flake-utils";
  # hermes-agent: pinned upstream at rev 1b1975781 (0.20.1) but OVERRIDDEN to a
  # local vendored checkout so we can carry one-line upstream fixes. Patches:
  #  - vendor/hermes-pr-guard.patch: kanban check_respawn_guard rule 4 `active_pr`
  #    had no escape for an operator re-queue, so a kanban_unblock of a card whose
  #    comments mention a PR url was silently ignored for the full 24h window,
  #    stranding fno-navigator boards (2026-08-20; card t_bdc26d91).
  #  - vendor/hermes-tool-search-sanitizer.patch: sanitize_api_messages now drops
  #    deferred tool_search tool_calls + their results. CommandCode's Responses
  #    conversion rejects the undeclared tool_search with "`input[N]` missing
  #    required field `arguments`", poisoning long threads on meta/muse-spark
  #    (2026-08-26; card t_f794c2ae).
  # The vendored tree == upstream @ 1b1975781 plus these patches.
  hermes-agent.url = "path:/home/smolpanda/nix-config/vendor/hermes-agent";
  # git+file:// (not path:) — path: inputs copy the whole dir and ignore
  # .gitignore, so .tmp-persist/ (2.2G scratch) + .git/ land in the input NAR
  # and every catalog run / commit flips narHash, breaking rebuild eval.
  d365fo-mcp.url = "git+file:///home/smolpanda/Fun/Projects/d365fo-mcp";
  d365fo-mcp.inputs.nixpkgs.follows = "nixpkgs-unstable";
  d365fo-mcp.inputs.flake-utils.follows = "flake-utils";
  sops-nix.url = "github:Mic92/sops-nix";
  # do NOT set inputs.nixpkgs.follows — let sops-nix use its own nixpkgs
  # (needs buildGo125Module, not available in 24.11)
};

outputs = { self, home-manager, nixpkgs, nixpkgs-unstable, nixpkgs-6e99f2a2, disko, hermes-agent, sops-nix, d365fo-mcp, ... }@inputs:
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    upkgs = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    pinnedPkgs = import nixpkgs-6e99f2a2 {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    specialArgs = { inherit pkgs upkgs pinnedPkgs; } // { inherit d365fo-mcp; };

    # Build sops-install-secrets using nixpkgs-unstable (has buildGo125Module).
    # The system nixpkgs (24.11) only ships up to buildGo124Module, so we
    # cannot let the sops-nix module build it against the system pkgs.
    sops-install-secrets = (import "${sops-nix}" { pkgs = upkgs; }).sops-install-secrets;
  in
  {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/laptop
          # nur.nixosModules.nur
          # sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.nixos = import ./hosts/laptop/home.nix;
            };
          }
        ];
      };

      nixos-box = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/desktop
          # nur.nixosModules.nur
          # sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              backupFileExtension = "backup"; # this will move existing files by appending the given file extension rather than exiting with an error.
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.nixos-box = import ./hosts/desktop/home.nix;
            };
          }
          ];
       };

       nixos-server = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs // { inherit sops-install-secrets; };
        system = system;
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/server
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              backupFileExtension = "backup";
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.nixos-server = import ./hosts/server/home.nix;
            };
          }
        ];
        };

       smolpanda = nixpkgs.lib.nixosSystem {
         specialArgs = specialArgs // { inherit sops-install-secrets; };
         system = system;
         modules = [
           disko.nixosModules.disko
           sops-nix.nixosModules.sops
           hermes-agent.nixosModules.default
           ./hosts/smolpanda
           home-manager.nixosModules.home-manager
           {
             home-manager = {
               backupFileExtension = "backup";
               useUserPackages = true;
               useGlobalPkgs = true; 
               extraSpecialArgs = specialArgs;
               users.smolpanda = import ./hosts/smolpanda/home.nix;
             };
           }
         ];
       };
     };
  };
}
