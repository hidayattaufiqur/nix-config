{ ... }:
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;

    # logRoot = "/var/log/nginx";
    # logError = "stderr debug";
  };
}
