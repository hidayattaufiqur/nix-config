{ pkgs, ... }:
let
  ontology-be = "/home/nixos-server/Fun/Projects/ontology-BE";
  vitesse = "/home/nixos-server/Fun/Projects/vitesse/dist";
in
{
  services.nginx = {
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

            proxy_connect_timeout       300;
            proxy_send_timeout          300;
            proxy_read_timeout          300;
            send_timeout                300;
          '';
        };
      };

      "blogablog.hidayattaufiqur.dev" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
        };
      };

      "tools.hidayattaufiqur.dev" = {
        locations."/cockpit/" = {
          proxyPass = "https://127.0.0.1:9090/cockpit/";
          extraConfig = ''
            # Required to proxy the connection to Cockpit
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Required for web sockets to function
            proxy_http_version 1.1;
            proxy_buffering off;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            # Pass ETag header from Cockpit to clients.
            # See: https://github.com/cockpit-project/cockpit/issues/5239
            gzip off;
          '';
        };

        locations."/portainer/" = {
          proxyPass = "https://127.0.0.1:9443/";
          extraConfig = ''
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Prefix /portainer/;

            rewrite ^/portainer/(.*) /$1 break;
            '';
        };
      };
    };
  };
}
