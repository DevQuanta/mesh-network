{ lib, ... }: {
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

    # Fixed: Moved here so downstream-local can see it
    remoteFRPPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
    };

    # Fixed: Added a separate port for the actual proxy pass-through to avoid port collision
    remoteFRPProxyPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
    };

    frpsToken = lib.mkOption {
      type = lib.types.str;
      description = "The secret token used to authenticate the downstream frpc connection.";
    };
  };
}
