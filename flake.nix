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

    # stolen from Mustafa's config
    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = [ "network-pre.target" "tailscale.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # have the job run this shell script
      script = with pkgs; ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
        if [ $status = "Running" ]; then # if so, then do nothing
          exit 0
        fi

        # otherwise authenticate with tailscale
        ${tailscale}/bin/tailscale up
      '';
    };

    systemd.services.logid-startup = {
      description = "Automatic startup for Logitech Daemon";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.logiops}/bin/logid";
        Restart = "on-failure";
      };  
    };

    systemd.services.keyboard-startup-fix = { 
      enable = true; 
      description = "Keychron enable fn keys mode";
      unitConfig = {
        Type = "simple";
      };

      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";

      script = '' 
        sleep 2
        echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode
      '';
    };
  };
}
