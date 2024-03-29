{ lib, stdenv, pkgs, ... }: 
let
  tmuxCustomConf = ''
    set -g mouse on

    unbind '"'
    unbind %

    bind | split-window -h
    bind - split-window -v

    unbind r
    bind r source-file ~/.config/tmux/.tmux.conf

    set -g default-terminal "tmux-256color"
    set -ga terminal-overrides ",*256col*:Tc"
    set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
    set-environment -g COLORTERM "truecolor"

    # Smart pane switching with awareness of Vim splits.
    # See: https://github.com/christoomey/vim-tmux-navigator
    is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
        | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
    bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
    bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
    bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
    bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
    tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
    if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
    if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
        "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

    bind-key -T copy-mode-vi 'C-h' select-pane -L 
    bind-key -T copy-mode-vi 'C-j' select-pane -D
    bind-key -T copy-mode-vi 'C-k' select-pane -U
    bind-key -T copy-mode-vi 'C-l' select-pane -R
    bind-key -T copy-mode-vi 'C-\' select-pane -l

    bind -r j resize-pane -D 
    bind -r k resize-pane -U 
    bind -r l resize-pane -R 
    bind -r h resize-pane -L 
    bind -r m resize-pane -Z

    bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
    bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"

    unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse

    set-option -g default-command "zsh"

    set -g base-index 1 
    setw -g pane-base-index 1 

    setw -g window-status-current-style "bold,fg=colour208"

    set -g status-position bottom
    set -g status-bg colour234
    set -g status-fg colour137
    set -g status-right '#[fg=colour234,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '
    set -g status-right-length 50
    set -g status-left-length 20

    set -g @resurrect-capture-pane-contents 'on'
    set -g @continuum-restore 'on'

    set -g @plugin 'sainnhe/tmux-fzf'
  '';
in 
{
   programs.tmux = { 
     enable = true; 
     shortcut = "a"; # global key leader (ctr+{shortcut})

     plugins = with pkgs.tmuxPlugins; [
       vim-tmux-navigator
       resurrect
       continuum
       tmux-fzf
       # { 
       #   plugin = dracula;
       #   extraConfig = ''
       #    set -g @dracula-show-powerline true
       #    set -g @dracula-refresh-rate 10
       #    run-shell ${dracula}/share/tmux-plugins/dracula/dracula.tmux
       #   '';
       # }
     ];

    keyMode = "vi";
    historyLimit = 7000;
    baseIndex = 1; 
    extraConfig = tmuxCustomConf;
  };
}
