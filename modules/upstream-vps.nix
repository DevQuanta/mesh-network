{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.meshNetwork;
in
{
  options.services.meshNetwork = {

    remoteFRPPort = lib.mkOption {
      type = lib.types.port;
      default = 8081;
    };

  };

  config = lib.mkIf cfg.enable (lib.mkMerge) [
    {
      services.caddy = {
        enable = true;

        # By using virtualHosts, NixOS automatically writes the Caddyfile
        # and wires up the TLS certificates from security.acme for us!
        virtualHosts = {
          "https://derp.${cfg.domain}" = {
            extraConfig = ''
              reverse_proxy 127.0.0.1:${toString cfg.derperPort}
            '';
          };

          "https://headscale.${cfg.domain}" = {
            extraConfig = ''
              reverse_proxy 127.0.0.1:${toString cfg.remoteFRPPort}
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
          bindPort = cfg.remoteFRPPort;
          auth = {
            type = "token";
            token = cfg.frpsToken;
          };
        };
      };
    }

  ];

}
