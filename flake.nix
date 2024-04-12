{
  description = "NixOS module for publising text files";

  outputs = { self, ... }: {
    nixosModules = {
      txt = import ./.;
      default = self.outputs.nixosModules.txt;
    };
    nixosModule = self.outputs.nixosModules.txt;
  };
}
