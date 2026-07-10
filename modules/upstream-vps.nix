{ config, lib, pkgs, ... }:

let
  cfg = config.services.meshNetwork;
in
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

    frpPort = lib.mkOption {
      type = lib.types.port;
      default = 8081;
    };

    frpsToken = lib.mkOption {
      type = lib.types.str;
      description = "The secret token used to authenticate the downstream frpc connection.";
    };

  };

  config = lib.mkIf cfg.enable (lib.mkMerge) [
    {
  services.caddy = {
    enable = true;

    # By using virtualHosts, NixOS automatically writes the Caddyfile
    # and wires up the TLS certificates from security.acme for us!
    virtualHosts = {
      "http://derp.${cfg.domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.derperPort}
      '';
    };

    "http://headscale.${cfg.domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString cfg.frpPort}
      '';
    };


    };
  };

  }

  {
    systemd.services.derper = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.tailscale}/bin/derper -a 127.0.0.1:${toString cfg.derperPort} -http-port ${toString cfg.derperPort} -certmode manual -hostname derp.${toString cfg.domain} -stun";
    };
  };

  }

   {
      services.frp = {
        enable = true;
        role = "server";
        settings = {
          bindPort = 7000;
          auth = {
            type = "token";
            token = cfg.frpsToken;
          };
        };
      };
    } 


  ];

}
