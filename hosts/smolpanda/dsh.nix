# DeepSeek Harness (DSH) on smolpanda.
#
# DSH is DeepSeek's first-party agent harness for V4-Pro/V4-Flash
# (github.com/deepseek-ai/deepseek-harness, MIT, npm @deepseek-ai/dsh).
# This host runs it through the OFFICIAL PYTHON SDK
# (deepseek-harness-sdk) rather than the npm CLI, because the npm package
# needs the native addon `node-addon-require-builtin`, whose prebuilt binary
# cannot read Node's internal loader on NixOS:
#
#   Unsupported/no-getter (x64 sysv getter is not a recognized this->field accessor)
#
# That fails on Node 20/22/24/26 alike, and `NARB_BACKEND=nodeabi` needs a
# local build the published package does not ship. The Python SDK bundles its
# own runtime (Node 24.21.0 + the `dsh` single-file exe) and avoids the addon.
#
# The wheel binaries are generic Linux ELF, so NixOS needs patchelf treatment
# (otherwise stub-ld refuses them with "NixOS cannot run dynamically linked
# executables intended for generic linux environments"). That is what the
# postFixup below does.
#
# MODEL: only deepseek-v4.1-flash is exposed (user decision 2026-10-22).
# DeepSeek V4-Pro / V4-Flash are deliberately NOT offered.
#
# ROUTING: CommandCode serves `deepseek/*` models on the OpenAI-compatible
# /provider/v1/chat/completions endpoint only. The stock `sdk-minimal` profile
# uses DeepSeek's Anthropic-style adapter (@deepseek-ai/dsh-llm-deepseek-api-key)
# which posts to /messages with a `thinking` field and fails two ways:
#   /provider/v1/messages -> "Model \"deepseek/deepseek-v4.1-flash\" is not
#                            supported on this endpoint."
#   openai-completions    -> "400 Invalid input at thinking"
# So the profile patch below disables the deepseek adapter and inserts the
# pi-ai adapter with api: openai-completions.
#
# The `insert:` key is REQUIRED: the standalone sdk-minimal tree has no
# llm-pi-ai row, so a bare `- id: llm-pi-ai` patch is silently ignored and
# the provider stays `deepseek-official`.
#
# PTY: NixOS has no /bin/bash, and node-pty's execvp then fails with
# "PTY shell exited during startup" on every tool call. terminal-bash must be
# pointed at the Nix-provided bash.
#
# ROLE: DSH runs LONG single-task sessions (read -> edit -> test -> iterate
# inside one persistent shell + one cached context). It is NOT a replacement
# for the Hermes tool loop: DSH has no Hermes skills, no MCP servers, no
# Hindsight memory, and no kanban. Hermes delegates a long coding job to
# `dsh-run` and keeps orchestration.
{ config, lib, pkgs, ... }:

let
  version = "0.2.1rc2";

  sdkWheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/d4/da/97d6b092e5221e13c8560d50d1e5f5c9eb8ad64a75f40196bf340572dd15/deepseek_harness_sdk-0.2.1rc2-py3-none-any.whl";
    sha256 = "30fc72c67f20ff4b46c6952087ea596fc70c2692001aa372185a24f9866bdc46";
  };

  runtimeWheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/01/f3/1f7b9ea37ece210a5e432089bd63d048b2c45acc910561ec5e730c46a532/deepseek_harness_runtime_bin-0.2.1rc2-py3-none-manylinux_2_28_x86_64.whl";
    sha256 = "0a0a4eb85a22cd9339972e6a5ced77a27ec791353a5b220e3e10b8cdbbdeca39";
  };

  # The two wheels unpacked into one site-packages tree.
  # NOTE: pip is NOT used - PEP 668 blocks pip inside the Nix build
  # ("externally-managed-environment"), and format = "wheel" enables the dist
  # output phase which fails ("no ./dist directory") because these wheels
  # ship no dist/ dir. So: format = "other" + dontUnpack + manual unzip.
  sdkLib = pkgs.python3.pkgs.buildPythonApplication {
    pname = "deepseek-harness-sdk";
    inherit version;
    format = "other";
    src = sdkWheel;
    dontUnpack = true;

    nativeBuildInputs = [ pkgs.unzip ];
    propagatedBuildInputs = [ pkgs.python3.pkgs.pydantic ];

    installPhase = ''
      site=$out/lib/python${pkgs.python3.version}/site-packages
      mkdir -p "$site"
      cd "$site"
      ${pkgs.unzip}/bin/unzip -q -o ${sdkWheel}
      ${pkgs.unzip}/bin/unzip -q -o ${runtimeWheel}
      chmod +x "$site"/deepseek_harness_runtime/runtime/* 2>/dev/null || true
    '';

    # The runtime ships generic Linux ELF binaries (the `dsh` single-file exe,
    # ripgrep). NixOS needs them repointed at the Nix glibc with an rpath that
    # includes libstdc++. Static binaries have no .interp - skip them.
    #
    # CRITICAL: do NOT strip these. The `dsh` exe is a Node single-file
    # application; its payload lives in a trailing section that `strip`
    # truncates (313MB -> the binary then dumps core on startup). stripDebug
    # is disabled for the whole output.
    dontStrip = true;

    postFixup = ''
      glibcLib="${pkgs.glibc}/lib"
      gccLib="${pkgs.libgcc.lib}/lib"
      while IFS= read -r bin; do
        [ -f "$bin" ] || continue
        if readelf -l "$bin" 2>/dev/null | grep -q INTERP; then
          patchelf --set-interpreter "$glibcLib/ld-linux-x86-64.so.2" "$bin"
          patchelf --set-rpath "$glibcLib:$gccLib" "$bin"
          echo "patchelf: $bin"
        else
          echo "skip (static): $bin"
        fi
      done < <(find "$out/lib" -type f \( -name 'deepseek-harness-sdk-runtime-linux-x64' -o -name 'deepseek-harness-sdk-runtime-linux-x64-rg' -o -name 'node' -o -name 'pnpm' \) 2>/dev/null)
    '';

    # pythonImportsCheck is DISABLED: this build installs the wheels by hand
    # in installPhase (PEP 668 blocks pip), so the import check runs before
    # the modules are in place and always fails. The import path is verified
    # by the dsh-run smoke test instead.
    pythonImportsCheck = [ ];

    meta = {
      description = "DeepSeek Harness Python SDK (DSH agent harness)";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };

  # Python env carrying the SDK's runtime deps (pydantic). The SDK itself is
  # exposed via PYTHONPATH - it is a buildPythonApplication, so withPackages
  # would drop it as a non-module.
  pythonEnv = pkgs.python3.withPackages (ps: [ pkgs.python3.pkgs.pydantic ]);

  # The DSH home holds the profile patch. The SDK never reads ~/.dsh
  # implicitly - dsh_home is always passed explicitly.
  dshHome = "/var/lib/hermes/dsh";

  profilePatch = pkgs.writeText "dsh-sdk-minimal-cordis.patch.yml" ''
    # DSH on NixOS + CommandCode routing (see hosts/smolpanda/dsh.nix).
    #
    # 1) PTY shell: NixOS has no /bin/bash, so node-pty's execvp fails and
    #    every tool call dies with "PTY shell exited during startup".
    # 2) LLM route: CommandCode serves deepseek/* only on the OpenAI-compatible
    #    /chat/completions endpoint, so use the pi-ai openai-completions
    #    adapter instead of DeepSeek's Anthropic-style adapter.
    - id: terminal-bash
      name: '@deepseek-ai/dsh-terminal-bash'
      config:
        shellPath: /run/current-system/sw/bin/bash
    - id: llm-deepseek
      name: '@deepseek-ai/dsh-llm-deepseek-api-key'
      disabled: true
    - insert:
      - id: llm-pi-ai
        name: '@deepseek-ai/dsh-llm-pi-ai'
        inject: [llm]
        config:
          providers:
            commandcode:
              displayName: CommandCode
              apiKeyEnv: COMMANDCODE_API_KEY
              api: openai-completions
              baseURL: https://api.commandcode.ai/provider/v1
              defaultContextWindow: 1000000
              models:
                - id: deepseek/deepseek-v4.1-flash
                  name: DeepSeek V4.1 Flash
                  contextWindow: 1000000
    - id: agent-default-model
      name: '@deepseek-ai/dsh-agent-default-model'
      config:
        provider: commandcode
        model: deepseek/deepseek-v4.1-flash
  '';

  # dsh-run: drive one long DSH session against CommandCode.
  dshRun = pkgs.writeShellApplication {
    name = "dsh-run";
    runtimeInputs = [ pythonEnv ];
    text = ''
      set -euo pipefail

      WORKSPACE="''${1:?usage: dsh-run <workspace> <session-id> <prompt> [max_tokens]}"
      SESSION="''${2:?usage: dsh-run <workspace> <session-id> <prompt> [max_tokens]}"
      PROMPT="''${3:?usage: dsh-run <workspace> <session-id> <prompt> [max_tokens]}"
      MAX_TOKENS="''${4:-8192}"

      export DSH_HOME="''${DSH_HOME:-${dshHome}}"
      export DSH_TELEMETRY_MODE="''${DSH_TELEMETRY_MODE:-OFF}"
      export PYTHONPATH="''${PYTHONPATH:+$PYTHONPATH:}${sdkLib}/lib/python${pkgs.python3.version}/site-packages"

      mkdir -p "$WORKSPACE"
      cd "$WORKSPACE"

      exec ${pythonEnv}/bin/python - "$WORKSPACE" "$SESSION" "$PROMPT" "$MAX_TOKENS" <<'PYEOF'
      import os
      import sys
      from deepseek_harness import DeepSeekHarness

      workspace, session_id, prompt, max_tokens = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

      with DeepSeekHarness(
          provider="commandcode",
          model="deepseek/deepseek-v4.1-flash",
          max_tokens=max_tokens,
          cwd=workspace,
          dsh_home=os.environ["DSH_HOME"],
          profile="sdk-minimal",
      ) as harness:
          result = harness.run(prompt, session_id=session_id)
          print(result.final_response)
      PYEOF
    '';
  };

  # Install script. systemd's ExecStart does NOT run through a shell, so a
  # multi-line command string is exec'd as one binary name and fails with
  # 203/EXEC ("Unable to locate executable 'mkdir'"). A real script fixes it.
  #
  # Runs as ROOT on purpose: it owns the DSH home's directory tree, so it can
  # repair a root-owned leftover from an earlier tmpfiles rule. It then drops
  # the tree to smolpanda:users, which is what the DSH process needs.
  installPatch = pkgs.writeShellApplication {
    name = "dsh-install-profile-patch";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      mkdir -p ${dshHome}/profiles/sdk-minimal
      chown -R smolpanda:users ${dshHome}
      chmod 0755 ${dshHome} ${dshHome}/profiles ${dshHome}/profiles/sdk-minimal
      cp -f ${profilePatch} ${dshHome}/profiles/sdk-minimal/cordis.patch.yml
      chown smolpanda:users ${dshHome}/profiles/sdk-minimal/cordis.patch.yml
      chmod 0644 ${dshHome}/profiles/sdk-minimal/cordis.patch.yml
    '';
  };

  dshCli = pkgs.writeShellApplication {
    name = "dsh";
    runtimeInputs = [ pythonEnv ];
    text = ''
      export PYTHONPATH="''${PYTHONPATH:+$PYTHONPATH:}${sdkLib}/lib/python${pkgs.python3.version}/site-packages"
      exec ${pythonEnv}/bin/python -c 'from deepseek_harness_runtime import main; import sys; sys.exit(main())' "$@"
    '';
  };
in
{
  environment.systemPackages = [ dshRun dshCli ];

  systemd.tmpfiles.rules = [
    # Declare EVERY level explicitly, owned by smolpanda. tmpfiles type "d"
    # creates missing parent components as ROOT, so a single nested rule
    # ("d .../dsh/profiles/sdk-minimal") left /var/lib/hermes/dsh/profiles
    # root-owned 0755 and the service's mkdir then failed with EACCES.
    "d ${dshHome} 0755 smolpanda users -"
    "d ${dshHome}/profiles 0755 smolpanda users -"
    "d ${dshHome}/profiles/sdk-minimal 0755 smolpanda users -"
  ];

  systemd.services.dsh-profile-patch = {
    description = "Install the DSH sdk-minimal profile patch (NixOS + CommandCode routing)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Root: the script owns the DSH home tree (repairs root-owned leftovers
      # from an earlier tmpfiles rule) and then hands it to smolpanda.
      User = "root";
      Group = "root";
      ExecStart = "${installPatch}/bin/dsh-install-profile-patch";
    };
    # Re-apply when the patch content changes.
    restartTriggers = [ profilePatch ];
  };
}
