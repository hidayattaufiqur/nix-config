{
description = "flakes configuration v1";

inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
};

outputs = { self, nixpkgs }@inputs:
  {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./swift.nix ];
      };
       nixos-box = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         modules = [ ./nixos-box.nix ];
       };
    };
  };
}
