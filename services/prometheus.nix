{ lib, config, ... }: 
let 
  cfg = config.services.prometheus;
in
{
  options.services.prometheus = {
    personal-server = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = []; 
      description = "Prometheus target for personal server";
    };

    ta-server-sg = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = []; 
      description = "Prometheus target for ta-server-sg";
    };

    ta-server-us = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = []; 
      description = "Prometheus target for ta-server-us";
    };
  };

  config = {
    services.prometheus = {
      enable = true;
      port = 9001;
      
      scrapeConfigs = [
        {
          job_name = "ta-server-sg-scraper";
          static_configs = [{
            targets = if cfg.ta-server-sg != [] then cfg.ta-server-sg else [ "127.0.0.1:9002" ];
          }];
        }
        {
          job_name = "ta-server-us-scraper";
          static_configs = [{
            targets = if cfg.ta-server-us != [] then cfg.ta-server-us else [ "127.0.0.1:9002" ];
          }];
        }
        {
          job_name = "personal-server-scraper";
          static_configs = [{
            targets = if cfg.personal-server != [] then cfg.personal-server else [ "127.0.0.1:9002" ];
          }];
        }
      ];
    };
  };
}
