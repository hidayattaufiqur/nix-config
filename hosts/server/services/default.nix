{ pkgs, ... }:

{
  imports = [
  ./server.nix 
  ];

  services.tailscale.enable = true; 
  
  # Enable the OpenSSH daemon.
  services.openssh = { 
    enable = true; 
    settings.PasswordAuthentication = false;
    extraConfig = "UseDns no";
  }; 

  # Remap capslock to escape 
  services.interception-tools =
    let
      itools = pkgs.interception-tools;
      itools-caps = pkgs.interception-tools-plugins.caps2esc;
    in
    {
    enable = true;
    plugins = [ itools-caps ];
    # requires explicit paths: https://github.com/NixOS/nixpkgs/issues/126681
    udevmonConfig = pkgs.lib.mkDefault ''
      - JOB: "${itools}/bin/intercept -g $DEVNODE | ${itools-caps}/bin/caps2esc -m 1 | ${itools}/bin/uinput -d $DEVNODE"
        DEVICE:
          EVENTS:
            EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
    '';
  };

  # Enable postgresql service
  services.postgresql = {
    enable = true;
    # ensureDatabases = [ "mydatabase" ];
    enableTCPIP = true;
    # port = 5432;
    # authentication = pkgs.lib.mkOverride 10 ''
    #   #...
    #   #type database DBuser origin-address auth-method
    #   # ipv4
    #   host  all      all     127.0.0.1/32   trust
    #   # ipv6
    #   host all       all     ::1/128        trust
    # '';
  };
}
