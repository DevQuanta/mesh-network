# Self-Hosted Mesh Network Infrastructure

## Status
**⚠️ Currently undergoing testing**

## Overview
This repository contains a declarative NixOS flake designed to deploy a self-hosted mesh network. It provisions a Headscale coordination server on a downstream local node and routes public traffic through an upstream Virtual Private Server (VPS) via a Fast Reverse Proxy (FRP) tunnel. The upstream node also hosts a Tailscale DERP relay server for NAT traversal. 

## Architecture
The infrastructure is separated into two primary environments connected by a TCP tunnel.

1. **Upstream Edge (VPS):** This acts as the public ingress point. It utilizes Caddy to handle SSL termination and reverse proxy routing. Public requests targeting the coordination server are routed through an FRP tunnel. This node also hosts the DERPER service for peer-to-peer network relaying (if direct connection fails).
2. **Downstream Node (Local Server):** This runs the Headscale coordination server. An FRP client connects outbound to the upstream edge, establishing the reverse tunnel and bypassing residential NAT restrictions (i.e. CGNAT).

## Repository Structure
* `flake.nix`: The entry point defining the system configurations and integration tests.
* `modules/common.nix`: Defines shared configuration options (domain name, shared ports, authentication tokens).
* `modules/upstream-vps.nix`: The system configuration for the edge server. Configures Caddy, `services.tailscale.derper`, and the `frps` server.
* `modules/downstream-local.nix`: The system configuration for the local node. Configures the Headscale control plane, the `frpc` client, and local Caddy ingress.
* `test.nix`: A standalone NixOS test file to verify integration inside a sandbox.

## Prerequisites
* A target machine running NixOS with Flakes enabled.
* A public domain name configured with A/AAAA records pointing to the public IP address of the upstream VPS.
* A secure cryptographic string to be used as the FRP authentication token.

## Usage

#### Global Shared Options (`modules/common.nix`)
* `services.meshNetwork.enable`: Activates the unified network module block.
* `services.meshNetwork.domain`: The top-level domain used for reverse proxy generation.
* `services.meshNetwork.frpsToken`: Hashed authentication secret for the control plane.
* `services.meshNetwork.derperPort`: Internal listener port for the coordination relay (Default: `8080`).
* `services.meshNetwork.remoteFRPPort`: Control port where the server binds and listens for incoming clients (Default: `7000`).
* `services.meshNetwork.remoteFRPProxyPort`: The destination port on the VPS where public traffic is captured and routed down the tunnel (Default: `8082`).

#### Upstream-Specific Parameters (`modules/upstream-vps.nix`)
None. 

#### Downstream-Specific Options (`modules/downstream-local.nix`)
* `services.meshNetwork.remoteIP`: The static, public IPv4 address of your Upstream VPS.
* `services.meshNetwork.localIP`: Loopback or local interface address for internal network binding (Default: `127.0.0.1`).
* `services.meshNetwork.headscalePort`: Internal network socket for the coordination daemon (Default: `8085`).
* `services.meshNetwork.headscaleMetricsPort`: Socket endpoint for internal logging and telemetry (Default: `9090`).
* `services.meshNetwork.dnsBase`: Base name configuration for internal Tailnet resolution (Default: `mesh`).
* `services.meshNetwork.localFRPPort`: The port targeted by the local FRP client proxy payload (Default: `80`).

```nix
# on upstream machine
services.meshNetwork.upstream = {
  enable = true;
  domain = "example.com";
  frpsToken = "your-secure-token-here";
  derperPort = 8080;
  remoteFRPPort = 7000;
  remoteFRPProxyPort = 8082;
};

# on downstream machine
services.meshNetwork.downstream = {
  enable = true;
  domain = "example.com";
  frpsToken = "your-secure-token-here";
  remoteIP = "1.2.3.4";
  localFRPPort = 80;
  headscalePort = 8085;
  headscaleMetricsPort = 9090;
  dnsBase = "mesh";
  localIP = "127.0.0.1";
};
```

Apply the configuration to your respective hosts using standard NixOS deployment mechanisms.

```bash
nixos-rebuild switch --flake .#upstreamEdge
nixos-rebuild switch --flake .#downstreamNode
```

### 3. Firewall

Ensure your cloud provider's external firewall allows the following inbound traffic to the upstream VPS. The internal NixOS firewall handles these automatically, but  cloud firewalls must be manually configured:

* **TCP 80** (HTTP / ACME Challenge)
* **TCP 443** (HTTPS)
* **TCP 7000** (FRP Server Bind Port, or your configured `remoteFRPPort`)
* **UDP 3478** (STUN traffic required for the DERP server)

## Integration Testing

This repository includes an offline testing integration test utilizing the `testers.nixosTest` framework. It provisions two QEMU virtual machines, links them via a virtual network interface, and asserts that the FRP tunnel establishes and routes HTTPS traffic successfully.

To execute the test headless:

```bash
nix flake check
```

