{ config, lib, pkgs, ... }:
let
  cfg = config.services.meshNetwork;
in {
  imports = [ ./common.nix ];

  options.services.meshNetwork = {
    localFRPPort         = lib.mkOption { type = lib.types.port; default = 80; };
    headscalePort        = lib.mkOption { type = lib.types.port; default = 8085; };
    headscaleMetricsPort = lib.mkOption { type = lib.types.port; default = 9090; };
    dnsBase              = lib.mkOption { type = lib.types.str;  default = "mesh"; };
    localIP              = lib.mkOption { type = lib.types.str;  default = "127.0.0.1"; };
    remoteIP             = lib.mkOption { type = lib.types.str; };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.caddy = {
        enable = true;
        virtualHosts = {
          "http://headscale.${cfg.domain}".extraConfig = ''
            reverse_proxy ${cfg.localIP}:${toString cfg.headscalePort}
          '';
        };
      };
    }

    {
      services.headscale = {
        enable = true;
        port = cfg.headscalePort;
        settings = {
          server_url = "https://headscale.${cfg.domain}";
          listen_addr = "${cfg.localIP}:${toString cfg.headscalePort}";
          metrics_listen_addr = "${cfg.localIP}:${toString cfg.headscaleMetricsPort}";

          dns = {
            magic_dns = true;
            base_domain = "${cfg.dnsBase}.${cfg.domain}";
            nameservers.global = [ "1.1.1.1" "1.0.0.1" ];
          };

          derp.server.enabled = false;
          derp.urls = [ ];
          derp.paths = [ "/etc/headscale/derp.yaml" ];
        };
      };
    }

    {
      environment.etc."headscale/derp.yaml".text = ''
        regions:
          900:
            regionid: 900
            regioncode: vps
            regionname: DO-VPS
            nodes:
              - name: 900a
                regionid: 900
                hostname: derp.${cfg.domain}
                ipv4: ${cfg.remoteIP}
                stunport: 3478
                stunonly: false
                derpport: ${toString cfg.derperPort}
      '';
    }

    {
      services.frp = {
        enable = true;
        role = "client";
        settings = {
          serverAddr = cfg.remoteIP;
          serverPort = cfg.remoteFRPPort;
          # Fixed syntax grouping to guarantee safe object building across standard formats
          auth = {
            method = "token";
            token = cfg.frpsToken;
          };
          proxies = [
            {
              name = "headscale-tcp-passthrough";
              type = "tcp";
              localIP = cfg.localIP;
              localPort = cfg.localFRPPort;
              remotePort = cfg.remoteFRPProxyPort;
            }
          ];
        };
      };
    }
  ]);
}
