{ config, lib, pkgs, modulesPath, ... }:
{
  # Configure bluetooth to fix Keychron connection delay problem 
  hardware.bluetooth = { 
    enable = true; 
    settings.General = { 
      Experimental = true; 
    #   FastConnectable = true; 
    #   ReconnectAttempts = 7; 
    #   ReconnectIntervals = "1, 2, 3"; 
    }; 
  };
}

