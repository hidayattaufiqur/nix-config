## Plans & Pending Work

### SOPS Setup

[sops-nix](https://github.com/Mic92/sops-nix) is the intended secrets manager for this config.
The `.sops.yaml` and `secrets/secrets.yaml` are already in place; the NixOS integration is pending.

#### Why it's deferred
The latest `sops-nix` requires `buildGo125Module`, which is not available in nixpkgs 24.11.
Pointing `sops-nix.inputs.nixpkgs.follows` at `nixpkgs-unstable` did not resolve the issue.
Revisit once nixpkgs is upgraded to 25.05+.

#### What to do when ready

1. **`flake.nix`** — add and wire up `sops-nix`:
   ```nix
   sops-nix.url = "github:Mic92/sops-nix";
   # do NOT set inputs.nixpkgs.follows — let sops-nix use its own nixpkgs
   # (needs buildGo125Module, not available in 24.11)
   ```
   Add `sops-nix.nixosModules.sops` to the `nixos-server` modules list.

2. **`hosts/server/default.nix`** — configure SOPS to decrypt via the server SSH host key:
   ```nix
   sops.defaultSopsFile = ../../secrets/secrets.yaml;
   sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
   sops.secrets."cloudflare/credentialsFile" = {
     owner = config.services.cloudflared.user;
     mode  = "0400";
   };
   ```

3. **`services/cloudflared.nix`** — use the sops-managed credentials path:
   ```nix
   credentialsFile = config.sops.secrets."cloudflare/credentialsFile".path;
   ```
   Then re-enable `./cloudflared.nix` in `services/default.nix`.

4. **`.sops.yaml`** — add the server SSH host key as a second age recipient so both
   your personal key and the server can decrypt:
   ```yaml
   keys:
     - &primary age17a38lr94taz6etpgkdexp42cv5xtpge3fnvus7x84wgydjj8f5sqvx8x3h
     # obtained via: ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
     - &server  age1jm4hay50pvnwz73jnp8agvg9waph9r2yepl4r8aueeg82uxmkdvsc2xhq4
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       key_groups:
         - age: [*primary, *server]
   ```

5. **Re-encrypt `secrets/secrets.yaml`** from a machine holding the primary age private key:
   ```sh
   sops updatekeys secrets/secrets.yaml
   git add secrets/secrets.yaml && git commit -m "secrets: re-encrypt for server host key"
   ```

#### Secrets that should be managed by SOPS
| Secret | SOPS key path | Current state |
|---|---|---|
| Cloudflare tunnel credentials JSON | `cloudflare/credentialsFile` | hardcoded file path on disk |
| mc-management env file | `mc/env` (new) | plain file at `/etc/mc-management.env` |
