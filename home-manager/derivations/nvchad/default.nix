{ stdenv, pkgs, fetchFromGithub }:
let
  custom = ../../programs/nvim/custom;
in
{
nvchad = stdenv.mkDerivation rec {
  pname = "nvchad";
  version = "";
  dontBuild = true;

  src = pkgs.fetchFromGitHub {
    owner = "NvChad";
    repo = "NvChad";
    rev = "c8777040fbda6a656f149877b796d120085cd918";
    sha256 = "sha256-J4SGwo/XkKFXvq+Va1EEBm8YOQwIPPGWH3JqCGpFnxY=";
  };

  installPhase = ''
    mkdir $out
    cp -r $src "$out/"
    mkdir -p "$out/lua/custom"
    cp -r ${custom}/* "$out/lua/custom/"
  '';

  meta = with lib; {
    description = "NvChad";
    homepage = "https://github.com/NvChad/NvChad";
    platforms = platforms.all;
    license = licenses.gpl3;
  };
};
}
