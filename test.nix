# test.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.testers.nixosTest {
  name = "mesh-network-isolation-test";

  nodes = {
    upstream = { ... }: {
      imports = [ ./modules/upstream-vps.nix ];
      networking.interfaces.eth1.ipv4.addresses = [{
        address = "192.168.56.10";
        prefixLength = 24;
      }];

      # FIX: Teach the upstream machine how to resolve the testbed domains locally
      networking.extraHosts = ''
        127.0.0.1 derp.testbed.local
        127.0.0.1 headscale.testbed.local
      '';

      services.meshNetwork = {
        enable = true;
        domain = "testbed.local";
        frpsToken = "super-secret-test-token";
      };
    };

    downstream = { ... }: {
      imports = [ ./modules/downstream-local.nix ];
      
      # FIXED: Added network interface mapping so the client can talk to the server
      networking.interfaces.eth1.ipv4.addresses = [{
        address = "192.168.56.11";
        prefixLength = 24;
      }];

networking.extraHosts = ''
        127.0.0.1 headscale.testbed.local
        192.168.56.10 derp.testbed.local
      '';

      services.meshNetwork = {
        enable = true;
        domain = "testbed.local";
        remoteIP = "192.168.56.10";
        frpsToken = "super-secret-test-token";
      };
    };
  };

  testScript = ''
    start_all()
    upstream.wait_for_unit("caddy.service")
    upstream.wait_for_open_port(7000)
    downstream.wait_for_unit("frp.service")
    downstream.wait_for_unit("headscale.service")
    upstream.wait_for_open_port(8082)
    upstream.succeed("curl -k https://derp.testbed.local")
  '';
}
