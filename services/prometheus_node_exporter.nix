{ config, ... }: 
{
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    port = 9002;
    # Prometheus scrapes this at 127.0.0.1:9002 — loopback is enough.
    listenAddress = "127.0.0.1";
  };
}
