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
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Fixed: mkMerge parentheses structure
      {
        networking.firewall.allowedTCPPorts = [
          80
          443
          cfg.remoteFRPPort
        ];

        networking.firewall.allowedUDPPorts = [ 3478 ];

        services.caddy = {
          enable = true;
          virtualHosts = {
            # Fixed: Removed the "https://" schema from host keys
            "derp.${cfg.domain}" = {
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString cfg.derperPort}
              '';
            };

            "headscale.${cfg.domain}" = {
              extraConfig = ''
                reverse_proxy 127.0.0.1:${toString cfg.remoteFRPProxyPort}
              '';
            };
          };
        };
      }

      {
        # Using the official native NixOS module for DERPER
        services.tailscale.derper = {
          enable = true;
          port = cfg.derperPort;
          stunPort = 3478;
          domain = "derp.${cfg.domain}";
          verifyClients = false; # Set to true if you want to lock it down to your tailnet only
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
    ]
  );
}
