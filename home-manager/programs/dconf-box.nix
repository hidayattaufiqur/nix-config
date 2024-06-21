# Generated via dconf2nix: https://github.com/gvolpe/dconf2nix
{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {
    "Connections" = {
      first-run = false;
    };

    "Extensions" = {
      window-height = 959;
      window-maximized = true;
      window-width = 1771;
    };

    "GWeather4" = {
      temperature-unit = "centigrade";
    };

    "Snapshot" = {
      capture-mode = "video";
      is-maximized = true;
      play-shutter-sound = false;
      show-composition-guidelines = true;
      window-height = 640;
      window-width = 800;
    };

    "Totem" = {
      active-plugins = [ "recent" "skipto" "autoload-subtitles" "vimeo" "movie-properties" "variable-rate" "screenshot" "mpris" "apple-trailers" "screensaver" "rotation" "save-file" "open-directory" ];
      repeat = true;
      subtitle-encoding = "UTF-8";
      subtitle-font = "Sans Bold 10";
    };

    "Weather" = {
      window-height = 946;
      window-maximized = false;
      window-width = 843;
    };

    "baobab/ui" = {
      is-maximized = true;
      window-size = mkTuple [ 960 600 ];
    };

    "calculator" = {
      accuracy = 9;
      angle-units = "degrees";
      base = 10;
      button-mode = "basic";
      number-format = "automatic";
      show-thousands = false;
      show-zeroes = false;
      source-currency = "";
      source-units = "degree";
      target-currency = "";
      target-units = "radian";
      window-maximized = false;
      window-size = mkTuple [ 360 512 ];
      word-size = 64;
    };

    "calendar" = {
      active-view = "week";
      week-view-zoom-level = 1.0;
      window-maximized = true;
      window-size = mkTuple [ 1238 849 ];
    };

    "clocks/state/window" = {
      maximized = false;
      panel-id = "world";
      size = mkTuple [ 870 690 ];
    };

    "control-center" = {
      last-panel = "display";
      window-state = mkTuple [ 1356 868 false ];
    };

    "desktop/a11y/interface" = {
      high-contrast = false;
      show-status-shapes = false;
    };

    "desktop/a11y/keyboard" = {
      togglekeys-enable = false;
    };

    "desktop/app-folders" = {
      folder-children = [ "Utilities" "YaST" "75403312-388c-4f0c-bd8f-e031f5c067ee" "64c21ba0-ac7e-4f12-87c0-7cfcd36d0fb7" ];
    };

    "desktop/app-folders/folders/3a55e74c-5857-4d38-9bfa-8251e65b75b8" = {
      apps = [ "base.desktop" "startcenter.desktop" "calc.desktop" "draw.desktop" "impress.desktop" "math.desktop" "writer.desktop" ];
      name = "Office";
    };

    "desktop/app-folders/folders/41b660f3-5bf5-4b4c-850a-cdcce271fb17" = {
      apps = [ "calibre-ebook-viewer.desktop" "calibre-ebook-edit.desktop" "calibre-gui.desktop" "calibre-lrfviewer.desktop" ];
      name = "Calibre";
      translate = false;
    };

    "desktop/app-folders/folders/64c21ba0-ac7e-4f12-87c0-7cfcd36d0fb7" = {
      apps = [ "org.gnome.clocks.desktop" "org.gnome.Calculator.desktop" "org.gnome.Calendar.desktop" "org.gnome.Music.desktop" "org.gnome.Totem.desktop" "org.gnome.Weather.desktop" ];
      name = "Gnome Apps";
      translate = false;
    };

    "desktop/app-folders/folders/73bc8df0-c690-4a28-8f62-b068b7efadba" = {
      apps = [ "org.gnome.clocks.desktop" "org.gnome.Weather.desktop" "org.gnome.Snapshot.desktop" "org.gnome.Totem.desktop" "org.gnome.Calendar.desktop" "org.gnome.Calculator.desktop" "org.gnome.Music.desktop" ];
      name = "Gnome";
      translate = false;
    };

    "desktop/app-folders/folders/75403312-388c-4f0c-bd8f-e031f5c067ee" = {
      apps = [ "org.kde.kdeconnect.app.desktop" "org.kde.kdeconnect.nonplasma.desktop" "org.kde.kdeconnect-settings.desktop" "org.kde.kdeconnect.sms.desktop" ];
      name = "KDE";
      translate = false;
    };

    "desktop/app-folders/folders/9f1217dd-88a7-4d93-8bf6-ab85bd001b38" = {
      apps = [ "org.kde.kdeconnect.nonplasma.desktop" "org.kde.kdeconnect.app.desktop" "org.kde.kdeconnect-settings.desktop" "org.kde.kdeconnect.sms.desktop" ];
      name = "KDE";
      translate = false;
    };

    "desktop/app-folders/folders/Pardus" = {
      categories = [ "X-Pardus-Apps" ];
      name = "X-Pardus-Apps.directory";
      translate = true;
    };

    "desktop/app-folders/folders/Utilities" = {
      apps = [ "gnome-abrt.desktop" "gnome-system-log.desktop" "nm-connection-editor.desktop" "org.gnome.baobab.desktop" "org.gnome.Connections.desktop" "org.gnome.DejaDup.desktop" "org.gnome.Dictionary.desktop" "org.gnome.DiskUtility.desktop" "org.gnome.eog.desktop" "org.gnome.Evince.desktop" "org.gnome.FileRoller.desktop" "org.gnome.fonts.desktop" "org.gnome.seahorse.Application.desktop" "org.gnome.tweaks.desktop" "org.gnome.Usage.desktop" "vinagre.desktop" "cups.desktop" "gparted.desktop" ];
      categories = [ "X-GNOME-Utilities" ];
      name = "X-GNOME-Utilities.directory";
      translate = true;
    };

    "desktop/app-folders/folders/YaST" = {
      categories = [ "X-SuSE-YaST" ];
      name = "suse-yast.directory";
      translate = true;
    };

    "desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file:///home/nixos-box/.local/share/backgrounds/2024-06-21-13-47-45-GPaRSufa0AQqcoj.jpeg";
      picture-uri-dark = "file:///home/nixos-box/.local/share/backgrounds/2024-06-21-13-47-45-GPaRSufa0AQqcoj.jpeg";
      primary-color = "#000000000000";
      secondary-color = "#000000000000";
    };

    "desktop/input-sources" = {
      sources = [ (mkTuple [ "xkb" "us" ]) ];
      xkb-options = [ "terminate:ctrl_alt_bksp" ];
    };

    "desktop/interface" = {
      clock-format = "12h";
      color-scheme = "prefer-dark";
      cursor-size = 24;
      cursor-theme = "Adwaita";
      enable-animations = true;
      font-antialiasing = "grayscale";
      font-hinting = "slight";
      font-name = "SourceSans3VF 11";
      font-rgba-order = "vbgr";
      gtk-key-theme = "Default";
      gtk-theme = "Andromeda";
      icon-theme = "Adwaita";
      overlay-scrolling = true;
      show-battery-percentage = true;
      text-scaling-factor = 0.9583333333333334;
      toolkit-accessibility = false;
    };

    "desktop/notifications" = {
      application-children = [ "org-gnome-settings" "org-gnome-console" "gnome-network-panel" "org-gnome-nautilus" "balena-etcher-electron" "brave-browser" "org-gnome-evolution-alarm-notify" "gnome-power-panel" "org-gnome-geary" "spotify" "org-gnome-characters" "org-gnome-epiphany" "code" "com-rafaelmardojai-blanket" "teams" "thunderbird" "org-telegram-desktop" "steam" "discord" "org-gnome-epiphany-webapp-b336fc558722224b7ffe98607055d55f0fe52450" "brave-cpnkikabndlekcboecllopbehjigkoid-default" "brave-hnpfjngllnobngcgfapefoaidbinmjnm-default" "brave-magkoliahgffibhgfkmoealggombgknl-default" "brave-jckaldkomadaenmmgladeopgmfbahfjm-default" "datagrip" "gnome-system-monitor" "org-gnome-texteditor" "org-gnome-baobab" "nemo" "brave-cifhbcnohmdccbgoicgdjpfamggdegmo-default" "org-gnome-evince" "org-gnome-fileroller" "org-gnome-eog" "alacritty" "org-wireshark-wireshark" "startcenter" "calc" "brave-okpoapmnfnmippaflfjhfinmojhnlihe-default" "brave-ongjfmlfklpejhedmolancinnlgcanij-default" "writer" "postman" "zotero" "org-gnome-clocks" "location-trash-" "virtualbox" "brave-eilembjdkfgodjkcjnpgpaenohkicgjd-default" "brave-gfjiemlnmgajmgihefeppogphdpjchab-default" "bruno" "impress" "org-gnome-extensions-desktop" "org-gnome-loupe" "org-qbittorrent-qbittorrent" "org-kde-kdeconnect-daemon" "brave-lmaeggldoobicpfcmafcmfmjcefcmpfe-default" "org-gnome-shell-extensions-gsconnect" "brave-ckjildnpancgepcoglebbhocjafmibjj-default" "gimp" "brave-dncfnooabckepijhdkmafdolecckbjoe-default" "brave-aaojkibadcoaidodcebphjiciibdjlhd-default" "brave-cadlkienfkclaiaibeoongdcgmdikeeg-default" ];
      show-banners = false;
    };

    "desktop/notifications/application/alacritty" = {
      application-id = "Alacritty.desktop";
    };

    "desktop/notifications/application/balena-etcher-electron" = {
      application-id = "balena-etcher-electron.desktop";
    };

    "desktop/notifications/application/blender" = {
      application-id = "blender.desktop";
    };

    "desktop/notifications/application/brave-aaojkibadcoaidodcebphjiciibdjlhd-default" = {
      application-id = "brave-aaojkibadcoaidodcebphjiciibdjlhd-Default.desktop";
    };

    "desktop/notifications/application/brave-browser" = {
      application-id = "brave-browser.desktop";
    };

    "desktop/notifications/application/brave-cadlkienfkclaiaibeoongdcgmdikeeg-default" = {
      application-id = "brave-cadlkienfkclaiaibeoongdcgmdikeeg-Default.desktop";
    };

    "desktop/notifications/application/brave-cifhbcnohmdccbgoicgdjpfamggdegmo-default" = {
      application-id = "brave-cifhbcnohmdccbgoicgdjpfamggdegmo-Default.desktop";
    };

    "desktop/notifications/application/brave-ckjildnpancgepcoglebbhocjafmibjj-default" = {
      application-id = "brave-ckjildnpancgepcoglebbhocjafmibjj-Default.desktop";
    };

    "desktop/notifications/application/brave-cpnkikabndlekcboecllopbehjigkoid-default" = {
      application-id = "brave-cpnkikabndlekcboecllopbehjigkoid-Default.desktop";
    };

    "desktop/notifications/application/brave-dncfnooabckepijhdkmafdolecckbjoe-default" = {
      application-id = "brave-dncfnooabckepijhdkmafdolecckbjoe-Default.desktop";
    };

    "desktop/notifications/application/brave-eilembjdkfgodjkcjnpgpaenohkicgjd-default" = {
      application-id = "brave-eilembjdkfgodjkcjnpgpaenohkicgjd-Default.desktop";
    };

    "desktop/notifications/application/brave-fcbmadhppfekhfoaelhfegnnglncpeon-default" = {
      application-id = "brave-fcbmadhppfekhfoaelhfegnnglncpeon-Default.desktop";
    };

    "desktop/notifications/application/brave-fmpnliohjhemenmnlpbfagaolkdacoja-default" = {
      application-id = "brave-fmpnliohjhemenmnlpbfagaolkdacoja-Default.desktop";
    };

    "desktop/notifications/application/brave-gfjiemlnmgajmgihefeppogphdpjchab-default" = {
      application-id = "brave-gfjiemlnmgajmgihefeppogphdpjchab-Default.desktop";
    };

    "desktop/notifications/application/brave-hnpfjngllnobngcgfapefoaidbinmjnm-default" = {
      application-id = "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default.desktop";
    };

    "desktop/notifications/application/brave-jckaldkomadaenmmgladeopgmfbahfjm-default" = {
      application-id = "brave-jckaldkomadaenmmgladeopgmfbahfjm-Default.desktop";
    };

    "desktop/notifications/application/brave-lmaeggldoobicpfcmafcmfmjcefcmpfe-default" = {
      application-id = "brave-lmaeggldoobicpfcmafcmfmjcefcmpfe-Default.desktop";
    };

    "desktop/notifications/application/brave-magkoliahgffibhgfkmoealggombgknl-default" = {
      application-id = "brave-magkoliahgffibhgfkmoealggombgknl-Default.desktop";
    };

    "desktop/notifications/application/brave-okpoapmnfnmippaflfjhfinmojhnlihe-default" = {
      application-id = "brave-okpoapmnfnmippaflfjhfinmojhnlihe-Default.desktop";
    };

    "desktop/notifications/application/brave-ongjfmlfklpejhedmolancinnlgcanij-default" = {
      application-id = "brave-ongjfmlfklpejhedmolancinnlgcanij-Default.desktop";
    };

    "desktop/notifications/application/brave-pjibgclleladliembfgfagdaldikeohf-default" = {
      application-id = "brave-pjibgclleladliembfgfagdaldikeohf-Default.desktop";
    };

    "desktop/notifications/application/bruno" = {
      application-id = "bruno.desktop";
    };

    "desktop/notifications/application/calc" = {
      application-id = "calc.desktop";
    };

    "desktop/notifications/application/code" = {
      application-id = "code.desktop";
    };

    "desktop/notifications/application/com-rafaelmardojai-blanket" = {
      application-id = "com.rafaelmardojai.Blanket.desktop";
    };

    "desktop/notifications/application/datagrip" = {
      application-id = "datagrip.desktop";
    };

    "desktop/notifications/application/discord" = {
      application-id = "discord.desktop";
    };

    "desktop/notifications/application/gimp" = {
      application-id = "gimp.desktop";
    };

    "desktop/notifications/application/gnome-network-panel" = {
      application-id = "gnome-network-panel.desktop";
    };

    "desktop/notifications/application/gnome-power-panel" = {
      application-id = "gnome-power-panel.desktop";
    };

    "desktop/notifications/application/gnome-system-monitor" = {
      application-id = "gnome-system-monitor.desktop";
    };

    "desktop/notifications/application/gparted" = {
      application-id = "gparted.desktop";
    };

    "desktop/notifications/application/impress" = {
      application-id = "impress.desktop";
    };

    "desktop/notifications/application/location-trash-" = {
      application-id = "location:trash:///.desktop";
    };

    "desktop/notifications/application/nemo" = {
      application-id = "nemo.desktop";
    };

    "desktop/notifications/application/org-gnome-baobab" = {
      application-id = "org.gnome.baobab.desktop";
    };

    "desktop/notifications/application/org-gnome-characters" = {
      application-id = "org.gnome.Characters.desktop";
    };

    "desktop/notifications/application/org-gnome-clocks" = {
      application-id = "org.gnome.clocks.desktop";
    };

    "desktop/notifications/application/org-gnome-console" = {
      application-id = "org.gnome.Console.desktop";
    };

    "desktop/notifications/application/org-gnome-eog" = {
      application-id = "org.gnome.eog.desktop";
    };

    "desktop/notifications/application/org-gnome-epiphany-webapp-b336fc558722224b7ffe98607055d55f0fe52450" = {
      application-id = "org.gnome.Epiphany.WebApp_b336fc558722224b7ffe98607055d55f0fe52450.desktop";
      enable = true;
    };

    "desktop/notifications/application/org-gnome-epiphany" = {
      application-id = "org.gnome.Epiphany.desktop";
    };

    "desktop/notifications/application/org-gnome-evince" = {
      application-id = "org.gnome.Evince.desktop";
    };

    "desktop/notifications/application/org-gnome-evolution-alarm-notify" = {
      application-id = "org.gnome.Evolution-alarm-notify.desktop";
    };

    "desktop/notifications/application/org-gnome-extensions-desktop" = {
      application-id = "org.gnome.Extensions.desktop.desktop";
    };

    "desktop/notifications/application/org-gnome-extensions" = {
      application-id = "org.gnome.Extensions.desktop";
    };

    "desktop/notifications/application/org-gnome-fileroller" = {
      application-id = "org.gnome.FileRoller.desktop";
    };

    "desktop/notifications/application/org-gnome-geary" = {
      application-id = "org.gnome.Geary.desktop";
    };

    "desktop/notifications/application/org-gnome-loupe" = {
      application-id = "org.gnome.Loupe.desktop";
    };

    "desktop/notifications/application/org-gnome-nautilus" = {
      application-id = "org.gnome.Nautilus.desktop";
    };

    "desktop/notifications/application/org-gnome-settings" = {
      application-id = "org.gnome.Settings.desktop";
    };

    "desktop/notifications/application/org-gnome-shell-extensions-gsconnect" = {
      application-id = "org.gnome.Shell.Extensions.GSConnect.desktop";
    };

    "desktop/notifications/application/org-gnome-texteditor" = {
      application-id = "org.gnome.TextEditor.desktop";
    };

    "desktop/notifications/application/org-kde-kdeconnect-daemon" = {
      application-id = "org.kde.kdeconnect.daemon.desktop";
    };

    "desktop/notifications/application/org-qbittorrent-qbittorrent" = {
      application-id = "org.qbittorrent.qBittorrent.desktop";
    };

    "desktop/notifications/application/org-telegram-desktop" = {
      application-id = "org.telegram.desktop.desktop";
    };

    "desktop/notifications/application/org-wireshark-wireshark" = {
      application-id = "org.wireshark.Wireshark.desktop";
    };

    "desktop/notifications/application/postman" = {
      application-id = "postman.desktop";
    };

    "desktop/notifications/application/spotify" = {
      application-id = "spotify.desktop";
    };

    "desktop/notifications/application/startcenter" = {
      application-id = "startcenter.desktop";
    };

    "desktop/notifications/application/steam" = {
      application-id = "steam.desktop";
    };

    "desktop/notifications/application/teams" = {
      application-id = "teams.desktop";
    };

    "desktop/notifications/application/thunderbird" = {
      application-id = "thunderbird.desktop";
    };

    "desktop/notifications/application/virtualbox" = {
      application-id = "virtualbox.desktop";
    };

    "desktop/notifications/application/writer" = {
      application-id = "writer.desktop";
    };

    "desktop/notifications/application/zotero" = {
      application-id = "zotero.desktop";
    };

    "desktop/peripherals/mouse" = {
      speed = -0.20661157024793386;
    };

    "desktop/peripherals/touchpad" = {
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };

    "desktop/privacy" = {
      old-files-age = mkUint32 30;
      recent-files-max-age = -1;
    };

    "desktop/screensaver" = {
      color-shading-type = "solid";
      lock-enabled = false;
      picture-options = "zoom";
      picture-uri = "file:///home/nixos-box/.local/share/backgrounds/2024-06-21-13-47-45-GPaRSufa0AQqcoj.jpeg";
      primary-color = "#000000000000";
      secondary-color = "#000000000000";
    };

    "desktop/search-providers" = {
      disabled = [ "org.gnome.Epiphany.desktop" ];
      sort-order = [ "org.gnome.Contacts.desktop" "org.gnome.Documents.desktop" "org.gnome.Nautilus.desktop" ];
    };

    "desktop/session" = {
      idle-delay = mkUint32 300;
    };

    "desktop/sound" = {
      event-sounds = false;
      theme-name = "__custom";
    };

    "desktop/wm/keybindings" = {
      activate-window-menu = [];
      close = [ "<Shift><Control>q" ];
      maximize = [];
      switch-input-source = [];
      switch-input-source-backward = [];
      toggle-fullscreen = [ "F11" ];
      toggle-maximized = [ "<Super>Down" ];
      unmaximize = [];
    };

    "desktop/wm/preferences" = {
      button-layout = "close,maximize,minimize:";
      num-workspaces = 6;
      theme = "Andromeda";
      workspace-names = [];
    };

    "eog/ui" = {
      sidebar = false;
    };

    "evince/default" = {
      continuous = true;
      dual-page = false;
      dual-page-odd-left = false;
      enable-spellchecking = true;
      fullscreen = false;
      inverted-colors = false;
      show-sidebar = false;
      sidebar-page = "links";
      sidebar-size = 148;
      sizing-mode = "free";
      window-ratio = mkTuple [ 1.611764705882353 1.2461355529131986 ];
      zoom = 0.4822530864197531;
    };

    "evolution-data-server" = {
      migrated = true;
    };

    "evolution-data-server/calendar" = {
      notify-window-height = 685;
      notify-window-paned-position = 423;
      notify-window-width = 922;
      notify-window-x = 30;
      notify-window-y = 26;
      reminders-past = [ "cc40c40db06006db53bf9976557d0e016b30b5ccn1692195b4ea9e84d75d1b9ca156d8407d90c3edft20240619T123000n1718773200n1718775000n1718785800nBEGIN:VEVENTrnDTSTART;TZID=Asia/Jakarta:20240619T123000rnDTEND;TZID=Asia/Jakarta:20240619T153000rnRRULE:FREQ=WEEKLY;BYDAY=WErnDTSTAMP:20240414T104637ZrnUID:78en3gi1m1cbamkqjns0nkj1rn@google.comrnCREATED:20240218T114235ZrnX-LIC-ERROR;X-LIC-ERRORTYPE=VALUE-PARSE-ERROR:No value for DESCRIPTION rn property. Removing entire property:rnLAST-MODIFIED:20240414T104637ZrnLOCATION:TULT 0601rnSEQUENCE:0rnSTATUS:CONFIRMEDrnSUMMARY:CII4O3-ANALISIS JEJARING SOSIALrnTRANSP:OPAQUErnX-LIC-ERROR;X-LIC-ERRORTYPE=VALUE-PARSE-ERROR:No value for DESCRIPTION rn property. Removing entire property:rnX-EVOLUTION-CALDAV-ETAG:63848774797rnRECURRENCE-ID;TZID=Asia/Jakarta:20240619T123000rnBEGIN:VALARMrnACTION:DISPLAYrnDESCRIPTION:This is an event reminderrnTRIGGER:-PT30MrnX-EVOLUTION-ALARM-UID:1692195b4ea9e84d75d1b9ca156d8407d90c3edfrnEND:VALARMrnEND:VEVENTrn" "cc40c40db06006db53bf9976557d0e016b30b5ccn4461334e68558a789d99ba34d10ca4f5b57419d4t20240618T140000n1718692200n1718694000n1718697600nBEGIN:VEVENTrnDTSTART;TZID=Asia/Jakarta:20240618T140000rnDTEND;TZID=Asia/Jakarta:20240618T150000rnRRULE:FREQ=WEEKLY;BYDAY=TUrnDTSTAMP:20240131T024557ZrnUID:3ubkr42m7ejep975pvqmbd2bdm@google.comrnCREATED:20240122T073627ZrnX-LIC-ERROR;X-LIC-ERRORTYPE=VALUE-PARSE-ERROR:No value for DESCRIPTION rn property. Removing entire property:rnLAST-MODIFIED:20240131T024557ZrnX-LIC-ERROR;X-LIC-ERRORTYPE=VALUE-PARSE-ERROR:No value for LOCATION rn property. Removing entire property:rnSEQUENCE:0rnSTATUS:CONFIRMEDrnSUMMARY:Cloud Run and App Engine 101 with Mas MuhajirrnTRANSP:OPAQUErnX-LIC-ERROR;X-LIC-ERRORTYPE=VALUE-PARSE-ERROR:No value for LOCATION rn property. Removing entire property:rnX-EVOLUTION-CALDAV-ETAG:63847788327rnRECURRENCE-ID;TZID=Asia/Jakarta:20240618T140000rnBEGIN:VALARMrnACTION:DISPLAYrnDESCRIPTION:This is an event reminderrnTRIGGER:-PT30MrnX-EVOLUTION-ALARM-UID:4461334e68558a789d99ba34d10ca4f5b57419d4rnEND:VALARMrnEND:VEVENTrn" ];
    };

    "file-roller/dialogs/extract" = {
      recreate-folders = true;
      skip-newer = false;
    };

    "file-roller/listing" = {
      list-mode = "as-folder";
      name-column-width = 250;
      show-path = false;
      sort-method = "name";
      sort-type = "ascending";
    };

    "file-roller/ui" = {
      sidebar-width = 200;
      window-height = 795;
      window-width = 1380;
    };

    "gnome-system-monitor" = {
      current-tab = "resources";
      logarithmic-scale = false;
      maximized = false;
      network-total-in-bits = false;
      resources-memory-in-iec = false;
      show-dependencies = false;
      show-whose-processes = "user";
      update-interval = 1000;
      window-height = 1041;
      window-state = mkTuple [ 1920 1049 0 0 ];
      window-width = 954;
    };

    "gnome-system-monitor/disktreenew" = {
      col-0-visible = true;
      col-0-width = 453;
      col-1-visible = true;
      col-1-width = 295;
      col-2-visible = true;
      col-2-width = 79;
      col-3-visible = true;
      col-3-width = 70;
      col-4-visible = false;
      col-4-width = 69;
      col-5-visible = true;
      col-5-width = 75;
      col-6-visible = true;
      col-6-width = 0;
      columns-order = [ 0 2 5 6 3 1 4 ];
      sort-col = 0;
      sort-order = 0;
    };

    "gnome-system-monitor/proctree" = {
      col-0-visible = true;
      col-0-width = 361;
      col-10-visible = false;
      col-11-visible = false;
      col-14-visible = true;
      col-14-width = 503;
      col-16-visible = false;
      col-17-visible = false;
      col-17-width = 48;
      col-18-visible = false;
      col-18-width = 70;
      col-19-visible = false;
      col-2-visible = false;
      col-2-width = 37;
      col-20-visible = false;
      col-21-visible = false;
      col-21-width = 59;
      col-23-visible = true;
      col-23-width = 116;
      col-3-visible = false;
      col-3-width = 90;
      col-4-visible = false;
      col-6-visible = false;
      col-6-width = 90;
      col-9-visible = false;
      col-9-width = 80;
      columns-order = [ 0 1 2 3 4 6 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 ];
      sort-col = 8;
      sort-order = 0;
    };

    "maps" = {
      last-viewed-location = [ 0.0 0.0 ];
      map-type = "MapsStreetSource";
      transportation-type = "pedestrian";
      window-maximized = true;
      zoom-level = 2;
    };

    "mutter" = {
      dynamic-workspaces = true;
      edge-tiling = false;
      workspaces-only-on-primary = true;
    };

    "mutter/keybindings" = {
      toggle-tiled-left = [];
      toggle-tiled-right = [];
    };

    "nautilus/compression" = {
      default-compression-format = "zip";
    };

    "nautilus/icon-view" = {
      captions = [ "type" "none" "none" ];
      default-zoom-level = "medium";
    };

    "nautilus/list-view" = {
      default-column-order = [ "name" "size" "type" "owner" "group" "permissions" "where" "date_modified" "date_modified_with_time" "date_accessed" "date_created" "recency" "detailed_type" ];
      default-visible-columns = [ "name" "size" "date_modified" ];
      default-zoom-level = "medium";
      use-tree-view = true;
    };

    "nautilus/preferences" = {
      default-folder-viewer = "list-view";
      migrated-gtk-settings = true;
      search-filter-time-type = "last_modified";
      search-view = "list-view";
      show-directory-item-counts = "always";
      show-image-thumbnails = "always";
    };

    "nautilus/window-state" = {
      initial-size = mkTuple [ 1271 841 ];
      maximized = true;
    };

    "nm-applet/eap/0c563460-8818-360a-bc2d-d7fbe777665b" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/2a29f0b2-fac2-430f-89b8-cc6bccd80652" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/31a9d28e-09b5-4cce-aa4f-ae909e3afbbf" = {
      ignore-ca-cert = true;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/32724775-9a3d-3ec6-a05b-06cf697c54f7" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/69f01810-7270-4c0d-b96b-1d704fd0c5c9" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/6db07d05-88ad-486a-9c9b-f9f8b1367db8" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/846b513f-dadd-4323-a644-961e136ca23d" = {
      ignore-ca-cert = true;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/a8f7d250-2559-4b73-91e4-050a7cd03a21" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/b5f7d12d-c208-4754-9461-ef7ba855b7ed" = {
      ignore-ca-cert = true;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/ba62904d-fba2-4aad-aaba-b213c83dee2c" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/c034c1b4-d422-3735-9f76-bf5bcf34c767" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "nm-applet/eap/d68aa00f-1b37-4075-be43-4ed371c30db1" = {
      ignore-ca-cert = false;
      ignore-phase2-ca-cert = false;
    };

    "photos" = {
      window-maximized = true;
      window-position = [ 30 26 ];
      window-size = [ 960 600 ];
    };

    "portal/filechooser/brave-browser" = {
      last-folder-path = "/home/nixos-box/Documents/Personal";
    };

    "portal/filechooser/brave-cpnkikabndlekcboecllopbehjigkoid-Default" = {
      last-folder-path = "/home/nixos-box/Downloads";
    };

    "portal/filechooser/brave-fcbmadhppfekhfoaelhfegnnglncpeon-Default" = {
      last-folder-path = "/home/nixos-box/Downloads";
    };

    "portal/filechooser/brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default" = {
      last-folder-path = "/home/nixos-box/Downloads";
    };

    "portal/filechooser/discord" = {
      last-folder-path = "/home/nixos-box/Downloads";
    };

    "portal/filechooser/org/gnome/Settings" = {
      last-folder-path = "/home/nixos-box/Pictures/Wallpaper";
    };

    "portal/filechooser/org/kde/kdeconnect-settings" = {
      last-folder-path = "/home/nixos-box/Documents/Books";
    };

    "portal/filechooser/org/kde/kdeconnect/app" = {
      last-folder-path = "/home/nixos-box/Pictures/Screenshots";
    };

    "portal/filechooser/org/telegram/desktop" = {
      last-folder-path = "/home/nixos-box/Pictures";
    };

    "portal/filechooser/rofi" = {
      last-folder-path = "/home/nixos-box/Pictures/Wallpaper";
    };

    "portal/filechooser/spotify" = {
      last-folder-path = "/home/nixos-box/Pictures";
    };

    "settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-temperature = mkUint32 4700;
    };

    "settings-daemon/plugins/media-keys" = {
      custom-keybindings = [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/" "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/" ];
    };

    "settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Control><Alt>t";
      command = "env -u WAYLAND_DISPLAY alacritty";
      name = "Open Terminal";
    };

    "settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Alt>space";
      command = "rofi -show drun -transient-window -no-lazy-grab";
      name = "Rofi Drun";
    };

    "settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super>e";
      command = "nemo";
      name = "Files";
    };

    "settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      binding = "<Alt>e";
      command = "rofi -show emoji -transient-window -no-lazy-grab";
      name = "Rofi Emoji";
    };

    "settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
      binding = "<Alt>c";
      command = "rofi -show calc -transient-window -no-lazy-grab";
      name = "Rofi Calc";
    };

    "settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
      binding = "<Alt>w";
      command = "rofi -show window -transient-window -no-lazy-grab";
      name = "Rofi Window";
    };

    "settings-daemon/plugins/media-keys/custom-keybindings/custom6" = {
      binding = "<Alt>c";
      command = "rofi -show calc -trainsient-window -no-lazy-grab";
      name = "Rofi Calc";
    };

    "settings-daemon/plugins/power" = {
      idle-dim = true;
      power-button-action = "nothing";
      sleep-inactive-ac-type = "nothing";
    };

    "shell" = {
      command-history = [ "ls" "pwd" "lg" "drun" "rofi" "rodi -drun" "rofi show -drun" "rofi -show drun" "sh -c -- \"rofi\"" "/bin/sh -c -- \"launcher_t1\"" "sh -c -- launcher_t1" ];
      disable-user-extensions = false;
      disabled-extensions = [ "windowsNavigator@gnome-shell-extensions.gcampax.github.com" "trayIconsReloaded@selfmade.pl" "places-menu@gnome-shell-extensions.gcampax.github.com" "drive-menu@gnome-shell-extensions.gcampax.github.com" "window-list@gnome-shell-extensions.gcampax.github.com" "workspace-indicator@gnome-shell-extensions.gcampax.github.com" "light-style@gnome-shell-extensions.gcampax.github.com" "apps-menu@gnome-shell-extensions.gcampax.github.com" "auto-move-windows@gnome-shell-extensions.gcampax.github.com" "peek-top-bar-on-fullscreen@marcinjahn.com" ];
      enabled-extensions = [ "screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com" "just-perfection-desktop@just-perfection" "blur-my-shell@aunetx" "user-theme@gnome-shell-extensions.gcampax.github.com" "appindicatorsupport@rgcjonas.gmail.com" "quick-settings-tweaks@qwreey" "compiz-alike-magic-lamp-effect@hermes83.github.com" "dash-to-dock@micxgx.gmail.com" "Resource_Monitor@Ory0n" "gsconnect@andyholmes.github.io" "tiling-assistant@leleat-on-github" "hidetopbar@mathieu.bidon.ca" "app-hider@lynith.dev" "native-window-placement@gnome-shell-extensions.gcampax.github.com" "rounded-window-corners@fxgn" ];
      favorite-apps = [ "thunderbird.desktop" "nemo.desktop" "brave-browser.desktop" "org.telegram.desktop.desktop" "discord.desktop" "spotify.desktop" "code.desktop" "brave-jckaldkomadaenmmgladeopgmfbahfjm-Default.desktop" "datagrip.desktop" ];
      last-selected-power-profile = "performance";
      welcome-dialog-last-shown-version = "44.2";
    };

    "shell/app-switcher" = {
      current-workspace-only = true;
    };

    "shell/extensions/app-hider" = {
      hidden-apps = [ "waydroid.com.android.inputmethod.latin.desktop" "org.gnome.Tour.desktop" "waydroid.org.lineageos.jelly.desktop" "waydroid.com.android.calculator2.desktop" "waydroid.org.lineageos.etar.desktop" "waydroid.com.android.camera2.desktop" "waydroid.com.android.deskclock.desktop" "waydroid.com.android.contacts.desktop" "waydroid.com.android.documentsui.desktop" "waydroid.com.android.gallery3d.desktop" "waydroid.com.android.settings.desktop" "waydroid.org.lineageos.recorder.desktop" "waydroid.org.lineageos.eleven.desktop" "waydroid.com.aurora.services.desktop" "waydroid.com.google.android.gms.desktop" "waydroid.com.android.vending.desktop" "waydroid.com.aurora.adroid.desktop" "org.gnome.Nautilus.desktop" ];
      hidden-search-apps = [];
    };

    "shell/extensions/appindicator" = {
      icon-brightness = -2.7755575615628914e-17;
      icon-opacity = 200;
      icon-saturation = 2.7755575615628914e-17;
      icon-size = 0;
      legacy-tray-enabled = true;
      tray-pos = "right";
    };

    "shell/extensions/auto-move-windows" = {
      application-list = [ "brave-browser.desktop:1" "brave-jckaldkomadaenmmgladeopgmfbahfjm-Default.desktop:3" "brave-cpnkikabndlekcboecllopbehjigkoid-Default.desktop:2" "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default.desktop:4" "discord.desktop:4" "org.telegram.desktop.desktop:4" "brave-magkoliahgffibhgfkmoealggombgknl-Default.desktop:4" ];
    };

    "shell/extensions/blur-my-shell" = {
      settings-version = 2;
    };

    "shell/extensions/blur-my-shell/appfolder" = {
      brightness = 0.6;
      sigma = 30;
    };

    "shell/extensions/blur-my-shell/dash-to-dock" = {
      blur = true;
      brightness = 0.52;
      override-background = true;
      sigma = 30;
      static-blur = true;
      style-dash-to-dock = 0;
    };

    "shell/extensions/blur-my-shell/overview" = {
      style-components = 2;
    };

    "shell/extensions/blur-my-shell/panel" = {
      brightness = 0.6;
      sigma = 30;
    };

    "shell/extensions/blur-my-shell/window-list" = {
      brightness = 0.6;
      sigma = 30;
    };

    "shell/extensions/dash-to-dock" = {
      apply-custom-theme = false;
      background-color = "rgb(17,18,22)";
      background-opacity = 0.95;
      click-action = "focus-minimize-or-appspread";
      custom-background-color = true;
      custom-theme-shrink = true;
      dash-max-icon-size = 32;
      dock-position = "BOTTOM";
      extend-height = false;
      height-fraction = 0.9;
      hide-tooltip = false;
      icon-size-fixed = false;
      intellihide = true;
      intellihide-mode = "FOCUS_APPLICATION_WINDOWS";
      isolate-locations = true;
      isolate-monitors = false;
      isolate-workspaces = false;
      middle-click-action = "launch";
      multi-monitor = false;
      preferred-monitor = -2;
      preferred-monitor-by-connector = "HDMI-1";
      pressure-threshold = 250.0;
      preview-size-scale = 0.1;
      running-indicator-style = "DOTS";
      shift-click-action = "minimize";
      shift-middle-click-action = "launch";
      show-apps-at-top = true;
      show-icons-notifications-counter = false;
      show-mounts = false;
      show-mounts-network = false;
      show-mounts-only-mounted = true;
      show-show-apps-button = false;
      transparency-mode = "FIXED";
    };

    "shell/extensions/just-perfection" = {
      accessibility-menu = true;
      activities-button = true;
      activities-button-icon-monochrome = true;
      activities-button-label = true;
      alt-tab-icon-size = 0;
      alt-tab-small-icon-size = 0;
      alt-tab-window-preview-size = 0;
      app-menu = true;
      app-menu-icon = true;
      clock-menu = true;
      clock-menu-position = 0;
      clock-menu-position-offset = 0;
      controls-manager-spacing-size = 0;
      dash-app-running = false;
      dash-icon-size = 0;
      dash-separator = true;
      hot-corner = false;
      keyboard-layout = true;
      osd = true;
      osd-position = 0;
      panel = true;
      panel-arrow = true;
      panel-button-padding-size = 7;
      panel-corner-size = 0;
      panel-icon-size = 12;
      panel-in-overview = true;
      panel-indicator-padding-size = 7;
      panel-notification-icon = true;
      panel-size = 24;
      power-icon = true;
      quick-settings = true;
      ripple-box = true;
      screen-sharing-indicator = true;
      search = true;
      show-apps-button = true;
      startup-status = 0;
      switcher-popup-delay = true;
      theme = false;
      top-panel-position = 0;
      weather = true;
      window-demands-attention-focus = false;
      window-picker-icon = true;
      window-preview-caption = true;
      window-preview-close-button = true;
      workspace = true;
      workspace-background-corner-size = 21;
      workspaces-in-app-grid = true;
      world-clock = true;
    };

    "shell/extensions/ncom/github/hermes83/compiz-alike-magic-lamp-effect" = {
      effect = "default";
    };

    "shell/extensions/quick-settings-tweaks" = {
      add-dnd-quick-toggle-enabled = true;
      add-unsafe-quick-toggle-enabled = false;
      datemenu-fix-weather-widget = true;
      datemenu-remove-notifications = false;
      disable-adjust-content-border-radius = false;
      disable-remove-shadow = false;
      list-buttons = "[{\"name\":\"SystemItem\",\"title\":null,\"visible\":true},{\"name\":\"OutputStreamSlider\",\"title\":null,\"visible\":true},{\"name\":\"InputStreamSlider\",\"title\":null,\"visible\":false},{\"name\":\"St_BoxLayout\",\"title\":null,\"visible\":true},{\"name\":\"BrightnessItem\",\"title\":null,\"visible\":true},{\"name\":\"NMWiredToggle\",\"title\":\"Wired\",\"visible\":true},{\"name\":\"NMWirelessToggle\",\"title\":\"Wi-Fi\",\"visible\":true},{\"name\":\"NMModemToggle\",\"title\":null,\"visible\":false},{\"name\":\"NMBluetoothToggle\",\"title\":null,\"visible\":false},{\"name\":\"NMVpnToggle\",\"title\":null,\"visible\":false},{\"name\":\"BluetoothToggle\",\"title\":\"Bluetooth\",\"visible\":true},{\"name\":\"PowerProfilesToggle\",\"title\":\"Power Mode\",\"visible\":false},{\"name\":\"NightLightToggle\",\"title\":\"Night Light\",\"visible\":true},{\"name\":\"DarkModeToggle\",\"title\":\"Dark Style\",\"visible\":true},{\"name\":\"KeyboardBrightnessToggle\",\"title\":\"Keyboard\",\"visible\":false},{\"name\":\"RfkillToggle\",\"title\":\"Airplane Mode\",\"visible\":true},{\"name\":\"RotationToggle\",\"title\":\"Auto Rotate\",\"visible\":false},{\"name\":\"DndQuickToggle\",\"title\":\"Do Not Disturb\",\"visible\":true},{\"name\":\"BackgroundAppsToggle\",\"title\":\"No Background Apps\",\"visible\":false},{\"name\":\"MediaSection\",\"title\":null,\"visible\":false}]";
      media-control-compact-mode = false;
      notifications-enabled = false;
      notifications-position = "bottom";
      notifications-use-native-controls = true;
      output-show-selected = false;
      user-removed-buttons = [];
      volume-mixer-enabled = true;
      volume-mixer-filtered-apps = [ "Blanket" ];
      volume-mixer-position = "top";
      volume-mixer-show-description = true;
      volume-mixer-show-icon = true;
      volume-mixer-use-regex = false;
    };

    "shell/extensions/rounded-window-corners" = {
      border-width = 0;
      settings-version = mkUint32 5;
    };

    "shell/extensions/tiling-assistant" = {
      activate-layout0 = [];
      activate-layout1 = [];
      activate-layout2 = [];
      activate-layout3 = [];
      active-window-hint = 1;
      active-window-hint-color = "rgb(0,169,245)";
      auto-tile = [];
      center-window = [];
      debugging-free-rects = [];
      debugging-show-tiled-rects = [];
      default-move-mode = 0;
      dynamic-keybinding-behavior = 0;
      import-layout-examples = false;
      last-version-installed = 47;
      restore-window = [ "<Super>Down" ];
      search-popup-layout = [];
      single-screen-gap = 4;
      tile-bottom-half = [ "<Super>KP_2" ];
      tile-bottom-half-ignore-ta = [];
      tile-bottomleft-quarter = [ "<Super>KP_1" ];
      tile-bottomleft-quarter-ignore-ta = [];
      tile-bottomright-quarter = [ "<Super>KP_3" ];
      tile-bottomright-quarter-ignore-ta = [];
      tile-edit-mode = [];
      tile-left-half = [ "<Super>Left" "<Super>KP_4" ];
      tile-left-half-ignore-ta = [];
      tile-maximize = [ "<Super>Up" "<Super>KP_5" ];
      tile-maximize-horizontally = [];
      tile-maximize-vertically = [];
      tile-right-half = [ "<Super>Right" "<Super>KP_6" ];
      tile-right-half-ignore-ta = [];
      tile-top-half = [ "<Super>KP_8" ];
      tile-top-half-ignore-ta = [];
      tile-topleft-quarter = [ "<Super>KP_7" ];
      tile-topleft-quarter-ignore-ta = [];
      tile-topright-quarter = [ "<Super>KP_9" ];
      tile-topright-quarter-ignore-ta = [];
      toggle-always-on-top = [];
      toggle-tiling-popup = [];
      window-gap = 4;
    };

    "shell/extensions/trayIconsReloaded" = {
      applications = "[{\"id\":\"spotify.desktop\",\"hidden\":false}]";
      icon-brightness = -10;
      icon-contrast = 0;
      icon-margin-vertical = 0;
      icon-padding-vertical = 0;
      icon-size = 16;
      icons-limit = 4;
      tray-margin-left = 0;
      tray-position = "right";
      wine-behavior = true;
    };

    "shell/extensions/user-theme" = {
      name = "Andromeda";
    };

    "shell/keybindings" = {
      screenshot = [ "<Super>Print" ];
      show-screen-recording-ui = [];
      show-screenshot-ui = [ "<Shift><Super>s" ];
    };

    "shell/weather" = {
      automatic-location = true;
    };

    "simple-scan" = {
      document-type = "photo";
    };
  };
}
