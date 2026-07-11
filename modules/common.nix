{ lib, ... }:

{
  options.services.meshNetwork = {
    enable = lib.mkEnableOption "My complete mesh networking infrastructure";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
      description = "The root domain used across the mesh network";
    };

    derperPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    frpsToken = lib.mkOption {
      type = lib.types.str;
      description = "The secret token used to authenticate the downstream frpc connection.";
    };

  };

}
