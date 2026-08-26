# Hindsight agent memory (self-hosted) — smolpanda only.
#
# Lightweight team memory layer. Hermes auto-recalls before every LLM call
# and auto-retains after, plus explicit retain/recall/reflect tools.
# Runs as a single Docker container with embedded pg0 (no external Postgres
# or Redis needed). Hermes connects at http://127.0.0.1:8888 via the native
# Hindsight memory provider (hermes memory setup hindsight).
#
# LLM inference for retain/reflect is routed through 9router
# (http://127.0.0.1:20128/v1) so it benefits from the existing
# hermes-agent Combo and cheap model routing.
{ config, lib, pkgs, ... }:

{
  # Secrets live in secrets-extra.yaml (agent-editable, no root needed).
  # Reuse the 9router API key for Hindsight's LLM calls so one Combo
  # controls cost. A separate access key protects the Hindsight API itself.
  sops.secrets."hindsight-access-key" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
  };
  sops.secrets."9router-api-key" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
  };

  # Env file for the Hindsight Docker container.
  # HINDSIGHT_API_LLM_* drives fact extraction and reflection.
  sops.templates."hindsight.env" = {
    content = ''
      HINDSIGHT_API_LLM_PROVIDER=openai
      HINDSIGHT_API_LLM_API_KEY=${config.sops.placeholder."9router-api-key"}
      HINDSIGHT_API_LLM_MODEL=hermes-agent
      HINDSIGHT_API_LLM_BASE_URL=http://127.0.0.1:20128/v1
      HINDSIGHT_API_TENANT_EXTENSION=hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension
      HINDSIGHT_API_TENANT_API_KEY=${config.sops.placeholder."hindsight-access-key"}
      HINDSIGHT_CP_ACCESS_KEY=${config.sops.placeholder."hindsight-access-key"}
      HINDSIGHT_CP_DATAPLANE_API_URL=http://127.0.0.1:8888
    '';
  };

  # Env file for Hermes gateways so the native Hindsight provider knows
  # where the self-hosted server lives. Env vars override
  # ~/.hermes/hindsight/config.json and take priority.
  sops.templates."hermes-hindsight.env" = {
    content = ''
      HINDSIGHT_MODE=cloud
      HINDSIGHT_API_URL=http://127.0.0.1:8888
      HINDSIGHT_API_KEY=${config.sops.placeholder."hindsight-access-key"}
      HINDSIGHT_BANK_ID=hermes-agent
      HINDSIGHT_AUTO_RECALL=true
      HINDSIGHT_AUTO_RETAIN=true
      HINDSIGHT_RECALL_BUDGET=mid
    '';
  };

  systemd.services.hindsight = {
    description = "Hindsight Agent Memory (self-hosted, embedded pg0)";
    after = [ "network.target" "docker.service" "9router.service" ];
    requires = [ "docker.service" ];
    wants = [ "9router.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      EnvironmentFile = config.sops.templates."hindsight.env".path;
      ExecStartPre = "-${pkgs.docker}/bin/docker rm -f hindsight";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name hindsight --network host --env-file ${config.sops.templates."hindsight.env".path} -v hindsight-data:/home/hindsight/.pg0 ghcr.io/vectorize-io/hindsight:latest";
      ExecStop = "-${pkgs.docker}/bin/docker stop hindsight";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
