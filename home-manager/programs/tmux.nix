{ upkgs, ... }: 
let
  tmuxCustomConf = ''
    set -g mouse on

    unbind '"'
    unbind %

    bind | split-window -h -c "#{pane_current_path}"
    bind - split-window -v -c "#{pane_current_path}"
    bind c new-window -c "#{pane_current_path}"

    set -g default-terminal "tmux-256color"
    set -ga terminal-overrides ",*256col*:Tc"
    set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
    set -ga terminal-overrides 'xterm*:smcup@:rmcup@'
    set-environment -g COLORTERM "truecolor"

    # Smart pane switching with awareness of Vim splits.
    # See: https://github.com/christoomey/vim-tmux-navigator
    if-shell '[ -f /.dockerenv ]' \
      "is_vim=\"ps -o state=,comm= -t '#{pane_tty}' \
          | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?)(diff)?$'\""
      # Filter out docker instances of nvim from the host system to prevent
      # host from thinking nvim is running in a pseudoterminal when its not.
      "is_vim=\"ps -o state=,comm=,cgroup= -t '#{pane_tty}' \
          | grep -ivE '^.+ +.+ +.+\\/docker\\/.+$' \
          | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?)(diff)? +'\""

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

    bind -n 'C-x' copy-mode
    bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
    bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"

    unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse

    set-option -g default-command "zsh"

    set -g base-index 1 
    setw -g pane-base-index 1 

    setw -g window-status-current-style "bold,fg=colour208"

    # set the pane border colors 
    set -g pane-border-style 'fg=colour235,bg=colour236' 
    set -g pane-active-border-style 'fg=colour51,bg=colour236'

    # set inactive/active window styles
    set-window-option -g window-active-style bg=terminal
    set-window-option -g window-style bg=colour0

    set -g status-position bottom
    set -g status-bg colour234
    set -g status-fg colour137
    set -g status-right '#[fg=colour234,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '
    set -g status-right-length 50
    set -g status-left-length 20

    set -ga update-environment EDITOR

    # this is for yazi image preview on terminal [https://yazi-rs.github.io/docs/image-preview#tmux]
    set -g allow-passthrough on
    set -ga update-environment TERM
    set -ga update-environment TERM_PROGRAM

    # TMUX plugins 
    set -g @plugin 'artemave/tmux_super_fingers'
    set -g @super-fingers-key f
    set -g @plugin 'sainnhe/tmux-fzf'
  '';
in 
{
   programs.tmux = { 
     enable = true; 
     shortcut = "a"; # global key leader (ctr+{shortcut})

     plugins = with upkgs.tmuxPlugins; [
       {
         plugin = resurrect; 
         extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
         '';
       }
       # {
       #   plugin = continuum; 
       #   extraConfig = ''
       #    set -g @continuum-restore 'on'
       #   '';
       # }
       tmux-fzf
     ];

    keyMode = "vi";
    historyLimit = 20000;
    baseIndex = 1; 
    extraConfig = tmuxCustomConf;
  };
}
