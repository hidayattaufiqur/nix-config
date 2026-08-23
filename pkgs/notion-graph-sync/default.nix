# notion-graph-sync — zero-runtime-deps TypeScript CLI. Pulls a curated subset
# of a Notion workspace via the API and emits a privacy-gated graph-data.json.
# No build step: Node >= 23.6 runs the .ts sources directly (native type
# stripping), so we just ship the src tree next to a node wrapper.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  nodejs_24, # satisfies engines ">=23.6" (native TS + global fetch)
}:
stdenvNoCC.mkDerivation {
  pname = "notion-graph-sync";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  buildPhase = ":";
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/notion-graph-sync $out/bin
    cp -r src package.json $out/lib/notion-graph-sync/

    makeWrapper ${nodejs_24}/bin/node $out/bin/notion-graph-sync \
      --add-flags "$out/lib/notion-graph-sync/src/main.ts"

    runHook postInstall
  '';

  meta = {
    description = "Notion workspace to privacy-safe knowledge graph JSON";
    mainProgram = "notion-graph-sync";
    platforms = lib.platforms.linux;
  };
}
