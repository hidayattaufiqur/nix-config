{ config, pkgs, ... }:

{
  services.redis.servers = {
    "nfo" = {
      enable = true;
      bind = "127.0.0.1";
      port = 6379;
    };
  };
}
