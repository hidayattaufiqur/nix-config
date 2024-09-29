{ pkgs, ... }:
{ 
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "hidayattaufiqur@gmail.com";
  
  services.nginx = {
    enable = true;
    package = pkgs.nginxQuic; # for HTTP/3
    eventsConfig = "worker_connections 2048;";
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    logError = "stderr debug";

    virtualHosts = {
      "ta-sg.hidayattaufiqur.dev" = {
        # other configs
        forceSSL = true;
        enableACME = true;

        ## HTTP/2
        # http2 = true;

        ## HTTP/3
        quic = true;
        http3 = true;
        reuseport = true;

        listenAddresses = [ "0.0.0.0" ];

        locations."/" = {
          proxyPass = "http://localhost:5000";
          extraConfig = ''
            add_header X-protocol $server_protocol always;
            add_header Alt-Svc 'h3-23=":443"; ma=3600, h2=":443"; ma=3600';
            add_header x-quic 'h3';
            add_header Cache-Control "no-cache,no_store"; 

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-protocol $server_protocol;
          '';
        };
      };
    };
  };
}
