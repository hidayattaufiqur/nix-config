{ pkgs, ... }:
let
  ontology-be = "/home/nixos-server/Fun/Projects/ontology-BE";
in
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    logError = "stderr debug";

    virtualHosts = {
      "ontology-api.hidayattaufiqur.dev" = {
        root = ontology-be;
        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
          extraConfig = ''
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Prefix /;
            proxy_set_header Content-Type application/json;
          '';
        };
      };

      "portainer.hidayattaufiqur.dev" = {
        locations."/" = {
          proxyPass = "https://127.0.0.1:9443";
        };
      };

      "blogablog.hidayattaufiqur.dev" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
        };
      };

    };
  };
}
