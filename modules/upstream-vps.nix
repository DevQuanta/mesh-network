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


  config = lib.mkIf cfg.upstream.enable (
    lib.mkMerge [
      {
        networking.firewall.allowedTCPPorts = [
          80
          443
          cfg.upstream.remoteFRPPort
        ];

        security.acme = {
          acceptTerms = true;
          defaults.email = cfg.upstream.defaultEmail;

        };

        services.nginx = {
          enable = true;
          streamConfig = ''
            map $ssl_preread_server_name $ssl_routing_backend {
                  derp.${toString cfg.upstream.domain}          127.0.0.2:${toString cfg.upstream.derperPort};
                  headscale.${toString cfg.upstream.domain}     127.0.0.1:${toString cfg.upstream.remoteFRPPort};
                }

            server {
                listen 443;

                ssl_preread on;
                proxy_pass $ssl_routing_backend;

                proxy_connect_timeout 5s;
                proxy_timeout 10m;
            }
          '';

          virtualHosts."derp.${toString cfg.upstream.domain}" = {
            serverName = cfg.upstream.domain;
            forceSSL = true; # Automatically redirect HTTP to HTTPS
            enableACME = true; # Triggers the automated ACME webroot challenge setup
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
              {
                addr = "[::]";
                port = 80;
              }
            ];

            root = "/var/www/html";
            locations."/".return = 404;

          };

        };

        networking.firewall.allowedUDPPorts = [ 3478 ];
      }

      {
        services.tailscale.derper = {
          enable = true;
          port = cfg.upstream.derperPort;
          stunPort = 3478;
          domain = "derp.${cfg.upstream.domain}";
          verifyClients = true;
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
