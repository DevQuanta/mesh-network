{ pkgs ? import <nixpkgs> {} }:

pkgs.testers.nixosTest {
  name = "mesh-network-isolation-test";

  nodes = {
    upstream = { lib, ... }: {
      imports = [ ./modules/upstream-vps.nix ];
      networking.interfaces.eth1.ipv4.addresses = [{
        address = "192.168.56.10";
        prefixLength = 24;
      }];

      # dns resolution
      networking.extraHosts = ''
        127.0.0.1 derp.testbed.local
        127.0.0.1 headscale.testbed.local
      '';

      services.meshNetwork.upstream = {
        enable = true;
        domain = "testbed.local";
        frpsToken = "super-secret-test-token";

        defaultEmail = "admin@testbed.local";
      };

      services.nginx.virtualHosts."derp.testbed.local".enableACME = lib.mkForce false;
      services.nginx.virtualHosts."derp.testbed.local".forceSSL = lib.mkForce false;
    };

    downstream = { lib, ... }: {
      imports = [ ./modules/downstream-local.nix ];
      
      # fix: network interface mapping so the client can talk to the server
      networking.interfaces.eth1.ipv4.addresses = [{
        address = "192.168.56.11";
        prefixLength = 24;
      }];

      networking.extraHosts = ''
        127.0.0.1 headscale.testbed.local
        192.168.56.10 derp.testbed.local
      '';

      # All configuration (including domain, token, and specific keys) inside the downstream block
      services.meshNetwork.downstream = {
        enable = true;
        domain = "testbed.local";
        frpsToken = "super-secret-test-token";
        remoteIP = "192.168.56.10";

        defaultEmail = "admin@testbed.local";
        dnsProvider = "cloudflare"; # Dummy value
        dnsVerificationFile = pkgs.writeText "dummy-dns-token" "token=123";
      };
      services.caddy.virtualHosts."http://headscale.testbed.local".extraConfig = lib.mkForce ''
        reverse_proxy 127.0.0.1:8085
      '';
    };
  };

  testScript = ''
    start_all()
    upstream.wait_for_unit("nginx.service")
    upstream.wait_for_open_port(7000)
    downstream.wait_for_unit("frp.service")
    downstream.wait_for_unit("headscale.service")
    upstream.wait_for_open_port(8082)
    upstream.succeed("curl -k http://derp.testbed.local")
  '';
}
