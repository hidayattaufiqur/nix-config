{ pkgs, ... }: 
{
  home.username = "nixos-server"; 
  home.homeDirectory = "/home/nixos-server";

  imports = [
    (import ../../home-manager/programs/nvim)
    (import ../../home-manager/programs/git.nix)
    (import ../../home-manager/programs/zsh.nix)
    (import ../../home-manager/programs/tmux.nix)
  ];

  programs = {
    fzf = {
      enable = true; 
      enableZshIntegration = true; 
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

    home.packages = with pkgs; [
      mosh
    # # adds the "hello" command to your environment. it prints a friendly
    # # "hello, world!" when run.
    # pkgs.hello

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
    # spotify-tui
  ];

  home.stateVersion = "23.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
