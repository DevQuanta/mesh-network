{ config, lib, pkgs, ... }:
let
  cfg = config.services.meshNetwork;
in
{
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.upstream.enable (
    lib.mkMerge [
      {
        networking.firewall.allowedTCPPorts = [
          80
          443
          cfg.upstream.remoteFRPPort
        ];

        networking.firewall.allowedUDPPorts = [ 3478 ];

        services.caddy = {
          enable = true;
          virtualHosts = {
            "derp.${cfg.upstream.domain}" = {
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString cfg.upstream.derperPort}
              '';
            };

            "headscale.${cfg.upstream.domain}" = {
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString cfg.upstream.remoteFRPProxyPort}
              '';
            };
          };
        };
      }

      {
        services.tailscale.derper = {
          enable = true;
          port = cfg.upstream.derperPort;
          stunPort = 3478;
          domain = "derp.${cfg.upstream.domain}";
          verifyClients = false; 
          configureNginx = false;
        };
      }

      {
        services.frp = {
          enable = true;
          role = "server";
          settings = {
            bindPort = cfg.upstream.remoteFRPPort;
            auth = {
              method = "token";
              token = cfg.upstream.frpsToken;
            };
          };
        };
      }
    ]
  );
}
