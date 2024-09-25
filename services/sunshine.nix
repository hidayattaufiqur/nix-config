{ pkgs, ... }: 
{
  services.sunshine = {
    enable = true;
    package = pkgs.sunshine;
  };

  security.wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
  };

  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  networking.firewall = {
    allowedTCPPorts = [ 47984 47989 47990 48010 ];
    allowedUDPPortRanges = [
      { from = 47998; to = 48000; }
      #{ from = 8000; to = 8010; }
    ];
  };

  boot.kernelModules = [ "uinput" ];
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';
}
