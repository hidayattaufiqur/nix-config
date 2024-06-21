{
  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        origins = "https://tools.hidayattaufiqur.dev wss://tools.hidayattaufiqur.dev";
        protocolHeader = "X-Forwarded-Proto";
        urlRoot = "/cockpit";
        allowUnencrypted = true;
      };
    };
  };
}
