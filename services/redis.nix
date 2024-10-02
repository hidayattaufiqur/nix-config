{ config, pkgs, ... }:

{
  # services.redis.servers."api-talent-report".enable=true;
  # services.redis.servers."api-talent-report".port=6379;

  services.redis.servers = {
    "default" = {
      enable = true;
      bind = "127.0.0.1";
      port = 6378;
    };
  };
}
