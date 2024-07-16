{ pkgs, ... }:
{ 
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "hidayattaufiqur@gmail.com";
  
  services.nginx = {
    enable = true;
    package = pkgs.nginxQuic; # for HTTP/3
    eventsConfig = "worker_connections 1024;";

    virtualHosts = {
      "ta-sg.hidayattaufiqur.dev" = {
        # other configs
        forceSSL = true;
        enableACME = true;

        ## HTTP/1.1
        # enableACME = true;

        ## HTTP/2
        # http2 = true;
        # enableACME = true;
        # forceSSL = true;

        ## HTTP/http3
        quic = true;
        http3 = true;
        reuseport = true;

        listenAddresses = [ "0.0.0.0" ];

        locations."/" = {
          proxyPass = "http://localhost:5000";
          extraConfig = ''
            add_header X-protocol $server_protocol always;
            add_header Alt-Svc  'h3=":$server_port"; ma=3600, h2=":$server_port"; ma=3600';
            add_header x-quic 'h3';
            add_header Cache-Control "no-cache,no_store"; 
          '';
        };
      };
    };
  };
}
