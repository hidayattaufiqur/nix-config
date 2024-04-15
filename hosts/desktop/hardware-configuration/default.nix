# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, upkgs, modulesPath, ... }:

{
  imports = [ 
    (modulesPath + "/installer/scan/not-detected.nix")
    ./bluetooth.nix
    ];

  # Bootloader.
   boot.loader = { 
     efi = { 
       # canTouchEfiVariables = true;
       efiSysMountPoint = "/boot/efi"; # if using grub
     };

     grub = { 
      enable = true; 
      device = "nodev";
      efiInstallAsRemovable = true; # in case canTouchEfiVariables doesn't work for your system
      efiSupport = true;  
      # useOSProber = true;  
      configurationLimit = 20;
     };
     timeout = 7;  
   };

  networking.hostName = "nixos-box"; # Define your hostname.

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "uas" "usb_storage" "sd_mod" ];
  boot.extraModulePackages = [ ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # AMD GPU stuffs (refer to https://nixos.wiki/wiki/AMD_GPU)
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.kernelParams = [ "amd_iommu=on" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ]; # enable HIP support

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    package = pkgs.mesa.drivers;
    package32 = pkgs.pkgsi686Linux.mesa.drivers;

    extraPackages = [ pkgs.mesa.opencl pkgs.rocmPackages.clr.icd pkgs.amdvlk ];
    extraPackages32 = [ pkgs.driversi686Linux.amdvlk ];
  };

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/a56584ed-7787-4050-8a09-2388e15d291a";
      fsType = "ext4";
    };

  fileSystems."/boot/efi" =
    { device = "/dev/disk/by-uuid/83DA-0099";
      fsType = "vfat";
    };
  
  swapDevices =
    [ { device = "/dev/disk/by-uuid/2b99bb38-51a9-4511-abb5-3d59ba220eb3"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # () this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp8s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
