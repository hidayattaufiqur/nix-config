{
description = "flakes configuration v1";

inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager.url = "github:nix-community/home-manager/release-23.11";
};

outputs = { self, home-manager, nixpkgs, nixpkgs-unstable }@inputs:
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

    specialArgs = inputs // { inherit system; };

    # shared-modules = [
    #   home-manager.nixosModules.home-manager
    #   {
    #     home-manager = {
    #       useUserPackages = true;
    #       useGlobalPkgs = true; 
    #       extraSpecialArgs = specialArgs;
    #
    #       users.nixos-box = import ./hosts/desktop/home.nix;
    #       users.nixos = import ./hosts/laptop/home.nix;
    #     };
    #   }
    # ];
  in
  {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules = [
          ./hosts/laptop/hardware-configuration/default.nix
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
        specialArgs = specialArgs // { inherit upkgs; };
        system = system;
        modules = [
          ./hosts/desktop/hardware-configuration/default.nix 
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true; 
              extraSpecialArgs = specialArgs // { inherit upkgs; };
              users.nixos-box = import ./hosts/desktop/home.nix;
            };
          }
          ];
       };
    };
  };
}
