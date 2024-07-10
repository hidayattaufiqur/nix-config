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

       gce-nixos-asia-southeast1-b = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/gce-nixos-asia-southeast1-b
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.server = import ./hosts/gce-nixos-asia-southeast1-b/home.nix;
            };
          }
        ];
       };

      gce-nixos-asia-southeast1-b-monitoring = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/gce-nixos-asia-southeast1-b-monitoring
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.server = import ./hosts/gce-nixos-asia-southeast1-b-monitoring/home.nix;
            };
          }
        ];
       };

      gce-nixos-us-central1-a = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/gce-nixos-us-central1-a
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs;
              users.server = import ./hosts/gce-nixos-us-central1-a/home.nix;
            };
          }
        ];
       };
    };
  };
}
