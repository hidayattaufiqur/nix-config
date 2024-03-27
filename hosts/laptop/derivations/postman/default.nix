{ stdenv, pkgs, inputs, system, ... }:

{
  stdenv.stdenv.mkDerivation (finalAttrs: {
    pname = "postman";
    version = "20230716100528";
    dontBuild = true; 

    src = pkgs.fetchurl {
      url = "https://web.archive.org/web/${version}/https://dl.pstmn.io/download/latest/linux_64";
      sha256 = "sha256-svk60K4pZh0qRdx9+5OUTu0xgGXMhqvQTGTcmqBOMq8=";
      # name = "${old.pname}-${version}.tar.gz";
    };

    installPhase = ''
      mkdir -p $out/bin
      tar -xzf $src -C $out/bin --strip-components=1
    '';

    meta = with lib; {
      description = "Postman";
      homepage = "https://www.postman.com/";
      platforms = platforms.linux;  # Adjust based on compatibility
      license = licenses.free;  # Update to the actual license
    };
  })
}
