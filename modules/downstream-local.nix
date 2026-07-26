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

  options.services.meshNetwork.downstream = {
    localFRPPort = lib.mkOption {
      type = lib.types.port;
      default = 80;
    };
    headscalePort = lib.mkOption {
      type = lib.types.port;
      default = 8085;
    };
    headscaleMetricsPort = lib.mkOption {
      type = lib.types.port;
      default = 9090;
    };
    dnsBase = lib.mkOption {
      type = lib.types.str;
      default = "mesh";
    };
    localIP = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    dnsProvider = lib.mkOption {
      type = lib.types.str;
    };

    dnsVerificationFile = lib.mkOption {
      type = lib.types.path;

    };
    remoteIP = lib.mkOption { type = lib.types.str; };
  };

  config = lib.mkIf cfg.downstream.enable (
    lib.mkMerge [
      {

        security.acme = {
          acceptTerms = true;
          defaults.email = cfg.downstream.defaultEmail;

          defaults.server = "https://acme-v02.api.letsencrypt.org/directory";
          certs."headscale.${cfg.downstream.domain}" = {
            domain = "headscale.${cfg.downstream.domain}";
            dnsProvider = cfg.downstream.dnsProvider;
            environmentFile = cfg.downstream.dnsVerificationFile;

            # dnsPropagationCheck = false;
            group = config.services.caddy.group;

            reloadServices = [ "caddy.service" ];
          };

        };

        services.caddy = {
          enable = true;
          virtualHosts = {
            "https://headscale.${cfg.downstream.domain}".extraConfig = ''
              reverse_proxy ${cfg.downstream.localIP}:${toString cfg.downstream.headscalePort}
            '';
          };
        };
      }

      {
        services.headscale = {
          enable = true;
          port = cfg.downstream.headscalePort;
          settings = {
            server_url = "https://headscale.${cfg.downstream.domain}";
            listen_addr = "${cfg.downstream.localIP}:${toString cfg.downstream.headscalePort}";
            metrics_listen_addr = "${cfg.downstream.localIP}:${toString cfg.downstream.headscaleMetricsPort}";

            dns = {
              magic_dns = true;
              base_domain = "${cfg.downstream.dnsBase}.${cfg.downstream.domain}";
              nameservers.global = [
                "1.1.1.1"
                "1.0.0.1"
              ];
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
                  hostname: derp.${cfg.downstream.domain}
                  ipv4: ${cfg.downstream.remoteIP}
                  stunport: 3478
                  stunonly: false
                  derpport: ${toString cfg.downstream.derperPort}
        '';
      }

      {
        services.frp = {
          enable = true;
          role = "client";
          settings = {
            serverAddr = cfg.downstream.remoteIP;
            serverPort = cfg.downstream.remoteFRPPort;
            auth = {
              method = "token";
              token = cfg.downstream.frpsToken;
            };
            proxies = [
              {
                name = "headscale-tcp-passthrough";
                type = "tcp";
                localIP = cfg.downstream.localIP;
                localPort = cfg.downstream.localFRPPort;
                remotePort = cfg.downstream.remoteFRPProxyPort;
              }
            ];
          };
        };
      }
    ]
  );
}
