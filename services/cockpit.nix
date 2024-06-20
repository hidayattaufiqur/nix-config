{
  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        allowUnencrypted = true;
      };
    };
  };
}
