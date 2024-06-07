{
description = "drunkwhales' personal flake configuration";

inputs = {
  nixpkgs-prev.url = "github:NixOS/nixpkgs/nixos-23.11";
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager.url = "github:nix-community/home-manager";
  home-manager.inputs.nixpkgs.follows = "nixpkgs";
  sops-nix.url = "github:Mic92/sops-nix";
  nur.url = "github:nix-community/NUR";
};

outputs = { self, home-manager, nixpkgs, nixpkgs-unstable, nur, sops-nix }@inputs:
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
        allowunfree = true;
      };
    };

    specialArgs = inputs // { inherit system pkgs upkgs; };
  in
  {
    inputs.pkgs = pkgs; 
    inputs.upkgs = upkgs;

    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs // { inherit upkgs; inherit pkgs; };
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
              extraSpecialArgs = specialArgs // { inherit upkgs; };
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
