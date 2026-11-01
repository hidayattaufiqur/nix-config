# nix-ld: run ordinary dynamically linked Linux binaries on NixOS.
#
# Hermes' browser toolset ships agent-browser as a prebuilt dynamically linked
# binary (glibc + libstdc++ paths baked in). NixOS has no /lib64/ld-linux at the
# standard path, so exec fails with the stub-ld message and browser_navigate
# cannot start even when the CDP endpoint is healthy:
#
#   Could not start dynamically linked executable:
#     ~/.npm/_npx/.../agent-browser-linux-x64
#   NixOS cannot run dynamically linked executables intended for generic
#   linux environments out of the box.
#
# nix-ld provides that loader and maps the usual shared libs into the
# environment, so the toolset's own driver works without patching or repackaging
# it. This is the supported NixOS mechanism for exactly this class of binary.
{ pkgs, ... }:
{
  programs.nix-ld.enable = true;

  # Libraries the browser driver (and typical node/native addons) link against.
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    libxml2
    libGL
    libgbm
    glib
    nss
    nspr
    dbus
    at-spi2-atk
    at-spi2-core
    cups
    expat
    libxkbcommon
    alsa-lib
    libdrm
    mesa
    pango
    cairo
  ];
}
