{ pkgs, ... }:
{
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "hidayattaufiqur@gmail.com";

  services.nginx = {
    # Harden and optimize nginx with sensible defaults
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    serverTokens = false;
    virtualHosts = {
      "hidayattaufiqur.dev" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:1977";
        };
      };

      # MC vhosts (mc/mcadmin/mcapi) removed 2026-08-08 with MC stack disable.

      # chat.hidayattaufiqur.dev — DISABLED 2026-08-08 (dead backend :3000,
      # gone with MC stack removal). Re-enable by uncommenting.
      # "chat.hidayattaufiqur.dev" = {
      #   forceSSL = true;
      #   enableACME = true;
      #   listenAddresses = [ "0.0.0.0" ];
      #
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:3000";
      #     extraConfig = ''
      #     # Add WebSocket support (Necessary for version 0.5.0 and up)
      #     proxy_http_version 1.1;
      #     proxy_set_header Upgrade $http_upgrade;
      #     proxy_set_header Connection "upgrade";
      #
      #     proxy_set_header Host $host;
      #     proxy_set_header X-Real-IP $remote_addr;
      #     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      #     proxy_set_header X-Forwarded-Proto $scheme;
      #
      #     # (Optional) Disable proxy buffering for better streaming response from models
      #     proxy_buffering off;
      #
      #     # increaing timeouts for long running requests
      #     proxy_send_timeout 2400;
      #     proxy_read_timeout 2400;
      #     proxy_connect_timeout 2400;
      #   '';
      #   };
      # };

      # n8n.hidayattaufiqur.dev — DISABLED 2026-08-08 (backend :5678 not
      # running). Re-enable by uncommenting.
      # "n8n.hidayattaufiqur.dev" = {
      #   forceSSL = true;
      #   enableACME = true;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:5678";
      #     extraConfig = ''
      #       proxy_http_version 1.1;
      #       proxy_set_header   Upgrade $http_upgrade;
      #       proxy_set_header   Connection "upgrade";
      #       proxy_set_header   Host $host;
      #       proxy_set_header   X-Real-IP $remote_addr;
      #       proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
      #       proxy_set_header   X-Forwarded-Proto $scheme;
      #     '';
      #   };
      #
      #   locations."/mcp/" = {
      #       proxyPass = "http://127.0.0.1:5678";
      #       extraConfig = ''
      #         proxy_http_version 1.1;
      #         proxy_set_header   Host $host;
      #         proxy_buffering    off;
      #         proxy_cache        off;
      #         gzip               off;
      #         proxy_read_timeout 3600;
      #         proxy_send_timeout 3600;
      #       '';
      #     };
      # };

      # notionmcp.hidayattaufiqur.dev — DISABLED 2026-08-08 (backend :6969 not
      # running). Re-enable by uncommenting.
      # "notionmcp.hidayattaufiqur.dev" = {
      #   forceSSL = true;
      #   enableACME = true;
      #   listenAddresses = [ "0.0.0.0" ];
      #
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:6969";
      #     extraConfig = ''
      #       proxy_http_version 1.1;
      #         proxy_set_header   Host $host;
      #         proxy_buffering    off;
      #         proxy_cache        off;
      #         gzip               off;
      #         proxy_read_timeout 3600;
      #         proxy_send_timeout 3600;
      #     '';
      #   };
      # };

      # "api.hidayattaufiqur.dev" = {
      #   root = ontology-be;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:5000";
      #     extraConfig = ''
      #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      #       proxy_set_header X-Forwarded-Proto $scheme;
      #       proxy_set_header X-Forwarded-Host $host;
      #       proxy_set_header X-Forwarded-Prefix /;
      #
      #       proxy_connect_timeout       300;
      #       proxy_send_timeout          300;
      #       proxy_read_timeout          300;
      #       send_timeout                300;
      #       client_max_body_size 20M;
      #     '';
      #   };
      # };

      # "ontology-api.hidayattaufiqur.dev" = {
      #   root = ontology-be;
      #   locations."/" = {
      #     proxyPass = "http://127.0.0.1:5000";
      #     extraConfig = ''
      #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      #       proxy_set_header X-Forwarded-Proto $scheme;
      #       proxy_set_header X-Forwarded-Host $host;
      #       proxy_set_header X-Forwarded-Prefix /;
      #
      #       proxy_connect_timeout       300;
      #       proxy_send_timeout          300;
      #       proxy_read_timeout          300;
      #       send_timeout                300;
      #       client_max_body_size 20M;
      #     '';
      #   };
      # };

      # fno.hidayattaufiqur.dev — production STATIC build (no vite dev server,
      # no websocket/HMR proxy; the vite ws was the CVE-2026-39363 surface).
      # Rebuild/deploy path: touch ~/.hermes/fno-deploy-trigger, which fires
      # the fno-deploy oneshot (see services/apps/systemd/fno-interactor.nix)
      # to npm run build + rsync build/ -> /var/lib/nginx/fno.
      "fno.hidayattaufiqur.dev" = {
        forceSSL = true;
        enableACME = true;
        root = "/var/lib/nginx/fno";
        locations."/" = {
          tryFiles = "$uri $uri/ /index.html";
        };
        extraConfig = ''
          # Cloudflare origin protection: only Cloudflare edge IPs may reach
          # this origin. Direct-origin requests (e.g. 103.74.5.153:443 with
          # Host: fno.hidayattaufiqur.dev) are rejected with 403. Ranges pinned
          # 2026-08-14 from https://www.cloudflare.com/ips-v4 and /ips-v6.
          allow 173.245.48.0/20;
          allow 103.21.244.0/22;
          allow 103.22.200.0/22;
          allow 103.31.4.0/22;
          allow 141.101.64.0/18;
          allow 108.162.192.0/18;
          allow 190.93.240.0/20;
          allow 188.114.96.0/20;
          allow 197.234.240.0/22;
          allow 198.41.128.0/17;
          allow 162.158.0.0/15;
          allow 104.16.0.0/13;
          allow 104.24.0.0/14;
          allow 172.64.0.0/13;
          allow 131.0.72.0/22;
          allow 2400:cb00::/32;
          allow 2606:4700::/32;
          allow 2803:f800::/32;
          allow 2405:b500::/32;
          allow 2405:8100::/32;
          allow 2a06:98c0::/29;
          allow 2c0f:f248::/32;
          deny all;

          # Security headers. CSP is same-origin-only with no framing/objects;
          # 'unsafe-inline' for script/style is required by the SvelteKit
          # prerendered bootstrap + inline critical styles (incl. graph pages).
          add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; upgrade-insecure-requests" always;
          add_header X-Frame-Options "DENY" always;
          add_header X-Content-Type-Options "nosniff" always;
          add_header Referrer-Policy "strict-origin-when-cross-origin" always;
          # HSTS pinned for this subdomain only (no includeSubDomains): other
          # subdomains on this dev domain are not guaranteed 100% HTTPS.
          add_header Strict-Transport-Security "max-age=31536000" always;
        '';
      };

      "blogablog.hidayattaufiqur.dev" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:4000";
        };
      };

      "nine-dots-hours.hidayattaufiqur.dev" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:4319";
        };
      };

      "websnag.hidayattaufiqur.dev" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:3002";
          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
      #
      # "tools.hidayattaufiqur.dev" = {
      #   locations."/cockpit/" = {
      #     proxyPass = "https://127.0.0.1:9090/cockpit/";
      #     extraConfig = ''
      #       # Required to proxy the connection to Cockpit
      #       proxy_set_header Host $host;
      #       proxy_set_header X-Forwarded-Proto $scheme;
      #
      #       # Required for web sockets to function
      #       proxy_http_version 1.1;
      #       proxy_buffering off;
      #       proxy_set_header Upgrade $http_upgrade;
      #       proxy_set_header Connection "upgrade";
      #
      #       # Pass ETag header from Cockpit to clients.
      #       # See: https://github.com/cockpit-project/cockpit/issues/5239
      #       gzip off;
      #     '';
      #   };
      #
      #   locations."/portainer/" = {
      #     proxyPass = "https://127.0.0.1:9443/";
      #     extraConfig = ''
      #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      #       proxy_set_header X-Forwarded-Proto $scheme;
      #       proxy_set_header X-Forwarded-Host $host;
      #       proxy_set_header X-Forwarded-Prefix /portainer/;
      #
      #       rewrite ^/portainer/(.*) /$1 break;
      #       '';
      #   };
      # };
    };
  };
}
