{ pkgs, ... }:
let
  ontology-be = "/home/nixos-server/Fun/Projects/ontology-BE";
  vitesse = "/home/nixos-server/Fun/Projects/vitesse/dist";
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
      "hidayattaufiqur.dev" = {
        locations."/" = {
          proxyPass = "http://localhost:1977";
        };
      };

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

      "blogablog.hidayattaufiqur.dev" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
        };
      };

      "tools.hidayattaufiqur.dev" = {
        locations."/portainer" = {
          proxyPass = "https://127.0.0.1:9443";
        };
        locations."/cockpit" = {
          proxyPass = "https://127.0.0.1:9090";
        };
      };
    };
  };
}
