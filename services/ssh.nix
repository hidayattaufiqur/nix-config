{
# Enable the OpenSSH daemon.
  services.openssh = { 
    enable = true; 
    settings.PasswordAuthentication = false;
    extraConfig = "UseDns no";
  }; 
}
