# Kubernetes deployment notes

Kustomize lives under **`deploy/`** (`deploy/base/` + root `deploy/kustomization.yaml`). Trial overlay: **`deploy/overlays/min-spec/`** (smaller PVC/requests, `game-servers` namespace, Harbor `imagePullSecrets`).

## Apply

```bash
kubectl apply -k deploy/
# Trial sizing + namespace game-servers (see overlay kustomization):
# kubectl apply -k deploy/overlays/min-spec/
```

Optional **`windrose-server-env`** `ConfigMap` from `.env` / `ServerDescription.json` workflow (see upstream README).

## Harbor, pinned tags, image pulls

- Image **`harbor.dataknife.net/library/windrose-server-k8s`** with a **pinned short SHA** in `deploy/base/kustomization.yaml`.
- **`imagePullPolicy: Always`** so CI can move the digest behind the same tag.
- **Private registry:** `imagePullSecrets` + `kubernetes.io/dockerconfigjson` secret.

## NFS and DepotDownloader

Windrose writes a large tree under **`/home/steam/server-files`**. On **NFS** (e.g. TrueNAS):

- **`chown`** from the container root user may **fail** (`root_squash`); init uses **best-effort** `chown` and runs **DepotDownloader as `steam`** so new files are not root-owned.
- If an **older** layout left **root-owned** `.DepotDownloader` or game files, DepotDownloader can throw **permission denied**; fix with a **one-time PVC cleanup** (scale Deployment to 0, remove stale dirs, scale up) or see merged fixes in `scripts/init.sh` / `scripts/functions.sh`.

## Service type: **ClusterIP**

The primary **`windrose-server`** `Service` is **`ClusterIP`**. Player-facing **TCP/UDP** ports are published through **Envoy Gateway** + **kube-vip** VIPs, not a second `LoadBalancer` on the game `Service` (avoids perpetual `<pending>` without MetalLB).

## How players connect

| Mode | What to give players |
|------|----------------------|
| **Invite code** (default) | Code from `ServerDescription.json` / env; players use in-game **Connect to server**. |
| **Direct connection** | Hostname or VIP + **7777 TCP/UDP** when `USE_DIRECT_CONNECTION=true`. |
| **Windrose+ dashboard** | **8780 TCP** on the same VIP/hostname if Windrose+ is enabled. |

Example DNS (DataKnife): **`windrose.dataknife.net`** → Envoy VIP (e.g. `192.168.14.186`). See **`DataKnifeAI/gitops-tools`** `docs/GAME_SERVERS_ENVOY.md` and `game-servers-exposure/overlays/prd-apps/`.

## kube-vip: use EnvoyProxy + `loadBalancerIP` (TCP+UDP Gateways)

If Envoy Gateway only sets **`spec.externalIPs`** for the Envoy **`Service`**, **kube-vip** may **not** bind the VIP on the node (**no `status.loadBalancer.ingress`**). Add a namespaced **`EnvoyProxy`** and reference it from **`Gateway.spec.infrastructure.parametersRef`**, with **`envoyService.loadBalancerIP`** matching **`Gateway.spec.addresses`** and **`externalTrafficPolicy: Cluster`** when Envoy runs on workers and the VIP is on control-plane nodes. See **`docs/examples/envoyproxy-kube-vip.example.yaml`** and **`docs/examples/gateway-tcp-udp.example.yaml`**.

## This repo vs gitops-tools

- **`deploy/`** here: app only (ClusterIP, workloads).
- **`docs/examples/`** here: **reference** YAML with placeholders for any cluster.
- **`gitops-tools` `game-servers-exposure/`**: DataKnife **Fleet** apply set (fixed VIPs, names, overlay path).

Avoid duplicating production manifests in this repo; keep **gitops-tools** as the single apply source for prd-apps, and update **examples** here when the integration pattern changes.

## Examples in this repo

**`docs/examples/`** holds reference YAML (**EnvoyProxy**, Envoy backend `Service`, `Gateway` + `TCPRoute`/`UDPRoute`). Production bundle for our cluster is maintained in **gitops-tools**.
