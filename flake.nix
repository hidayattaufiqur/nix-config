{
description = "drunkwhales' personal flake configuration";

inputs = {
  nixpkgs-6e99f2a2.url = "github:nixos/nixpkgs/6e99f2a27d600612004fbd2c3282d614bfee6421";
  nixpkgs-prev.url = "github:NixOS/nixpkgs/nixos-23.11";
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager/release-24.05";
    # inputs.nixpkgs.follows = "nixpkgs"; # this will follow 24.11 instead of 24.05
  };
  # sops-nix.url = "github:Mic92/sops-nix";
  # nur.url = "github:nix-community/NUR";

  # yazi.url = "github:sxyazi/yazi";
};

outputs = { self, home-manager, nixpkgs, nixpkgs-prev, nixpkgs-unstable, nixpkgs-6e99f2a2 }@inputs:
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    ppkgs = import nixpkgs-prev { 
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

    specialArgs = { inherit system pkgs ppkgs upkgs pinnedPkgs; };
    # TODO: make the modules import work so that it can be re-used accross hosts
    # modules = [ nur.nixosModules.nur sops-nix.nixosModules.sops home-manager.nixosModules.home-manager ]; 
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
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.nixos-box = import ./hosts/desktop/home.nix;
            };
          }
          ];
       };

      nixos-server = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/server
          # sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.nixos-server = import ./hosts/server/home.nix;
            };
          }
        ];
       };
    };
  };
}
