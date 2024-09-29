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
  };

  config = {
    services.prometheus = {
      enable = true;
      port = 9001;

      globalConfig = {
        scrape_interval = "5s";
      };
      
      scrapeConfigs = [
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
