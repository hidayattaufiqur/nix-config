{ pkgs, yazi, ... }:
let
	plugins-repo = pkgs.fetchFromGitHub {
		owner = "yazi-rs";
		repo = "plugins";
		rev = "main";
		hash = "";
	};
in
{
	programs.yazi = {
		enable = true;
    package = yazi.packages.${pkgs.system}.default;
    enableZshIntegration = true;
		shellWrapperName = "fm";

		plugins = {
			chmod = "${plugins-repo}/chmod.yazi";
			full-border = "${plugins-repo}/full-border.yazi";
			max-preview = "${plugins-repo}/max-preview.yazi";
			# starship = upkgs.fetchFromGitHub {
			# 	owner = "Rolv-Apneseth";
			# 	repo = "starship.yazi";
			# 	rev = "...";
			# 	sha256 = "sha256-...";
			# };
      glow = pkgs.fetchFromGitHub {
        owner = "Reledia"; 
        repo = "glow.yazi";
        rev = "main";
        hash = "";
      };

      miller = pkgs.fetchFromGitHub {
        owner = "Reledia";
        repo = "miller.yazi";
        rev = "main";
        hash = "";
      };
		};

    # Configuration written to $XDG_CONFIG_HOME/yazi/yazi.toml.
		settings = {
			manager = {
				show_hidden = true;
			};
			preview = {
				max_width = 1000;
				max_height = 1000;
			};
      prepend_viewers = [
        {
          name = "*.md";
          run = "glow";
        }
        {
          mime = "text/csv";
          run = "miller";
        }
      ];
		};

		initLua = ./init.lua;

	  # Configuration written to $XDG_CONFIG_HOME/yazi/keymap.toml.
    keymap = {
			manager.prepend_keymap = [
				{
					on = ["T"];
					run = "plugin --sync max-preview";
					desc = "Maximize or restore the preview pane";
				}
				{
					on = ["c" "m"];
					run = "plugin chmod";
					desc = "Chmod on selected files";
				}
			];
		};
	};
}
