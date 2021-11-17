{
  description = "NixOS module for publising text files";

  outputs = { self, nixpkgs, ... }: {
    nixosModule = import ./.;
  };
}
