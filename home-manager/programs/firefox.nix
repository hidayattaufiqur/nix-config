{ pinnedPkgs, ... }:
{
  programs.firefox = {
    enable = true;
    package = pinnedPkgs.firefox;
    nativeMessagingHosts = [ pinnedPkgs.firefoxpwa ];
  };
}
