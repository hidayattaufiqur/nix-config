# Browser Use configuration
{ config, lib, pkgs, ... }:

{
  # Add browser-use to system packages via PATH
  # The browser-use tool is installed via uv tool install
  # We need to ensure it's available in the PATH for all users
  
  environment.variables = {
    # Add uv tools directory to PATH
    PATH = lib.mkAfter [ "/home/smolpanda/.local/bin" ];
  };
  
  # Create a wrapper script for browser-use that sets the correct PATH
  environment.etc."browser-use-wrapper.sh" = {
    text = ''
      #!/bin/sh
      export PATH="/home/smolpanda/.local/bin:$PATH"
      exec browser-use "$@"
    '';
    mode = "0755";
  };
  
  # Add browser-use to system packages with proper PATH
  environment.systemPackages = with pkgs; [
    # Browser dependencies
    chromium
    xdg-utils
  ];
}
