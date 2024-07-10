{ lib, config, ... }: 
let 
  cfg = config.services.prometheus;
in
{
  options.services.prometheus = {
    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of targets to scrape.";
    };
  };

  config = {
    services.prometheus = {
      enable = true;
      port = 9001;
      
      scrapeConfigs = [
        {
          job_name = "prometheus-scraper";
          static_configs = [{
            targets = if cfg.targets != [] then cfg.targets else [ "127.0.0.1:9002" ];
          }];
        }
      ];
    };
  };
}
