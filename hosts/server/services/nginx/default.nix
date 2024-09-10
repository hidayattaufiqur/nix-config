{ pkgs, ... }:
let
  ontology-be = "/home/nixos-server/Fun/Projects/ontology-BE";
  hidayattaufiqurDev = "/home/nixos-server/Fun/Projects/hidayattaufiqur.dev/dist";
in
{
  services.nginx = {
    virtualHosts = {
      "teknofest.proclub.tech" = {
        locations."/" = {
          proxyPass = "http://localhost:3000";
        };
      };

      "hidayattaufiqur.dev" = {
        locations."/" = {
          proxyPass = "http://localhost:1977";
        };
      };

      "eigen-tc-api.hidayattaufiqur.dev" = {
        locations."/" = {
          proxyPass = "http://localhost:7342";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
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

            proxy_connect_timeout       300;
            proxy_send_timeout          300;
            proxy_read_timeout          300;
            send_timeout                300;
            client_max_body_size 20M;
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
