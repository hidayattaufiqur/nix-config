{
description = "drunkwhales' personal flake configuration";

inputs = {
  nixpkgs-prev.url = "github:NixOS/nixpkgs/nixos-23.11";
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager/release-24.05";
    # inputs.nixpkgs.follows = "nixpkgs";
  };
  sops-nix.url = "github:Mic92/sops-nix";
  nur.url = "github:nix-community/NUR";
};

outputs = { self, home-manager, nixpkgs, nixpkgs-prev, nixpkgs-unstable, nur, sops-nix }@inputs:
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
        allowunfree = true;
      };
    };

    upkgs = import nixpkgs-unstable {
      inherit system;
      config = {
        allowunfree = true;
      };
    };

    specialArgs = inputs // { inherit system pkgs ppkgs upkgs; };
  in
  {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/laptop
          nur.nixosModules.nur
          sops-nix.nixosModules.sops
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
          nur.nixosModules.nur
          sops-nix.nixosModules.sops
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
          nur.nixosModules.nur
          sops-nix.nixosModules.sops
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
