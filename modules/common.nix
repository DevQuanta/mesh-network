{ lib, config, ... }: 
let
  sharedOptions = {
    domain = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
      description = "The root domain used across the mesh network";
    };

    derperPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    remoteFRPPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
    };

    remoteFRPProxyPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
    };

    frpsToken = lib.mkOption {
      type = lib.types.str;
      description = "The secret token used to authenticate the downstream frpc connection.";
    };
  };
in {
  options.services.meshNetwork = {
    # inject common properties into upstream
    upstream = lib.mkOption {
      default = {};
      type = lib.types.submodule {
        options = sharedOptions // {
          enable = lib.mkEnableOption "the Upstream VPS Edge service";
        };
      };
    };

    # inject common properties into downstream
    downstream = lib.mkOption {
      default = {};
      type = lib.types.submodule {
        options = sharedOptions // {
          enable = lib.mkEnableOption "the Downstream local Node service";
        };
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !(config.services.meshNetwork.upstream.enable && config.services.meshNetwork.downstream.enable);
        message = "You cannot enable both services.meshNetwork.upstream and services.meshNetwork.downstream on the same machine.";
      }
    ];
  };
}
