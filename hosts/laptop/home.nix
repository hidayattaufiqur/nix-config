{ config, pkgs, ... }:
let
  nvchad = with pkgs; callPackage ../nvchad/default.nix { };
in
{
  home.username = "nixos";
  home.homeDirectory = "/home/nixos";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.

  imports = [
    (import ../../home-manager/programs/git.nix)
    (import ../../home-manager/programs/zsh.nix)
    (import ../../home-manager/programs/rofi.nix)
    (import ../../home-manager/programs/tmux.nix)
    (import ../../home-manager/programs/mimeapps.nix)
    (import ../../home-manager/programs/nvim/nvim.nix)
    (import ../../home-manager/programs/alacritty/alacritty.nix)
  ];

  programs.neovim = { 
   enable = true; 
   defaultEditor = true; 
   plugins = with pkgs.vimPlugins; [ 
    nvim-treesitter
    elixir-tools-nvim
    nvchad-ui
    catppuccin-nvim
    ];
  };

  programs.git = {
   enable = true; 
   userName = "Hidayat Taufiqur"; 
   userEmail = "hidayattaufiqur@gmail.com";
  };

  programs.fzf.enable = true;
  programs.fzf.enableZshIntegration = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # adds the "hello" command to your environment. it prints a friendly
    # # "hello, world!" when run.
    # pkgs.hello
    pkgs.google-cloud-sdk
    pkgs.nix-index
    pkgs.xclip
    pkgs.golangci-lint
    pkgs.gopls
    pkgs.xdotool
    pkgs.wtype
    pkgs.zip 
    pkgs.qbittorrent
    pkgs.winbox

    # # it is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. you can do that directly here, just don"t forget the
    # # parentheses. maybe you want to install nerd fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "fantasquesansmono" ]; })

    # # you can also create simple shell scripts directly inside your
    # # configuration. for example, this adds a command "my-hello" to your
    # # environment:
    # (pkgs.writeshellscriptbin "my-hello" ""
    #   echo "hello, ${config.home.username}!"
    # "")
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through "home.file".
  home.file = {
    # # Building this configuration will create a copy of "dotfiles/screenrc" in
    # # the Nix store. Activating the configuration will then make "~/.screenrc" a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ""
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # "";
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/nixos/etc/profile.d/hm-session-vars.sh
  #
  # if you don"t want to manage your shell through Home Manager.
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
