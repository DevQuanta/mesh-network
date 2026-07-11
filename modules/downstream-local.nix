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

    remoteIP = lib.mkOption {
      type = lib.types.str;
    };

  };

  config = lib.mkIf cfg.enable (lib.mkMerge) [
    # --------------------------------------------------------
    # 2. STANDARD CADDY (No custom compilation needed!)
    # --------------------------------------------------------
    {
      services.caddy = {
        enable = true;

        # By using virtualHosts, NixOS automatically writes the Caddyfile
        # and wires up the TLS certificates from security.acme for us!
        virtualHosts = {

          "http://headscale.${cfg.domain}" = {
            extraConfig = ''
              reverse_proxy ${toString cfg.localIP}:${toString cfg.headscalePort}
            '';
          };

        };
      };

    }

    {
      # 2. Headscale Control Plane
      services.headscale = {
        enable = true;
        port = cfg.headscalePort;
        settings = {
          server_url = "mesh.${toString cfg.domain}";
          listen_addr = "${toString cfg.localIP}:${toString cfg.headscalePort}";
          metrics_listen_addr = "${toString cfg.localIP}:${toString cfg.headscaleMetricsPort}";

          # --- DNS Block
          dns = {
            magic_dns = true;
            # The base domain your machines will use (e.g., 'laptop.headscale.yourdomain.com')
            base_domain = "${toString cfg.dnsBase}.${toString cfg.domain}";

            nameservers = {
              # The public DNS servers your nodes will use for normal web traffic
              global = [
                "1.1.1.1"
                "1.0.0.1"
              ];
            };
          };
          # --------------------------

          # Disable embedded DERP, use local file for VPS DERP
          derp.server.enabled = false;
          derp.urls = [ ];
          derp.paths = [ "/etc/headscale/derp.yaml" ];
        };
      };
    }

    # 3. Inject the DERP Map declarative file
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
                hostname: derp.${toString cfg.domain}
                ipv4: ${toString cfg.remotIP}
                stunport: 3478
                stunonly: false
                derpport: ${toString cfg.derperPort}
      '';
    }

    {
      # 4. FRP Client
      services.frp = {
        enable = true;
        role = "client";
        settings = {
          serverAddr = "${toString cfg.remoteIP}";
          serverPort = ${cfg.remoteFRPPort};
          auth.method = "token";
          auth.token = ${toString cfg.frpsToken};
          proxies = [
            {
              name = "headscale-tcp-passthrough";
              type = "tcp";
              localIP = "${toString cfg.localIP}";
              localPort = "${toString cfg.localFRPPort}";
              remotePort = ${cfg.remoteFRPPort};
            }
          ];
        };
      };
    }
  ];

}
