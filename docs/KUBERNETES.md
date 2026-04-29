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

### Envoy `TCPRoute` and **invite-only** (`USE_DIRECT_CONNECTION=false`)

Envoy’s **`TCPRoute` to :7777** performs a **plain TCP connect** to the pod. With **`UseDirectConnection": false`** the dedicated server often **does not listen for game TCP on 7777** in a way Envoy can reach (ICE / invite path is different). Logs may still show **BL gRPC on `127.0.0.1:42875`** — that is **not** the same socket as **`0.0.0.0:7777`**.

If Envoy access logs show **`delayed_connect_error:_Connection_refused`** (or **`UF,URX`**) to **`10.42.x.x:7777`**, first confirm the process accepts **TCP** on 7777 (e.g. `kubectl exec` + `ss -lntp` / `netstat` inside the container). For **VIP / DNS exposure through Envoy**, set **`USE_DIRECT_CONNECTION=true`** and **`DIRECT_CONNECTION_PROXY_ADDRESS=0.0.0.0`** (see README: invite vs direct connection trade-offs). The **`min-spec`** overlay sets these so **`deploy/envoy/`** TCP routing matches a listening port.

**`windrose-server-env`:** the Deployment references an **optional** `ConfigMap` with that name; if it is missing, no env is injected from it (expected unless you create the ConfigMap).

## How players connect

| Mode | What to give players |
|------|----------------------|
| **Invite code** (default) | Code from `ServerDescription.json` / env; players use in-game **Connect to server**. |
| **Direct connection** | Hostname or VIP + **7777 TCP/UDP** when `USE_DIRECT_CONNECTION=true`. **Required** for Envoy **TCP** :7777 to succeed unless the game binds TCP there in invite-only mode (usually it does not). |
| **Windrose+ dashboard** | **8780 TCP** on the same VIP/hostname if Windrose+ is enabled. |

Example DNS (DataKnife): **`windrose.dataknife.net`** → Envoy VIP (e.g. `192.168.14.186`).

## Envoy Gateway manifests (`deploy/envoy/`)

Apply **after** the game workload when using Envoy Gateway + kube-vip:

```bash
kubectl apply -k deploy/envoy/
```

VIP and namespace are in **`deploy/envoy/kustomization.yaml`**, **`envoyproxy.yaml`**, and **`gateway.yaml`**.

## kube-vip: use EnvoyProxy + `loadBalancerIP` (TCP+UDP Gateways)

If Envoy Gateway only sets **`spec.externalIPs`** for the Envoy **`Service`**, **kube-vip** may **not** bind the VIP on the node (**no `status.loadBalancer.ingress`**). Add a namespaced **`EnvoyProxy`** and reference it from **`Gateway.spec.infrastructure.parametersRef`**, with **`envoyService.loadBalancerIP`** matching **`Gateway.spec.addresses`** and **`externalTrafficPolicy: Cluster`** when Envoy runs on workers and the VIP is on control-plane nodes. See **`docs/examples/`** (placeholders) or **`deploy/envoy/`** (concrete VIPs).

## Examples in this repo

- **`deploy/envoy/`** — apply-ready Envoy + kube-vip bundle.
- **`docs/examples/`** — reference YAML with placeholders.

## Verification and troubleshooting (Envoy + logs)

**Confirm the game is listening (Windrose + direct connection)**  
After enabling **`USE_DIRECT_CONNECTION=true`** (and **`DIRECT_CONNECTION_PROXY_ADDRESS=0.0.0.0`** for Envoy TCP), **`R5.log`** should show direct mode and a bind on all interfaces, for example:

- `SaveServerDescription` / persisted JSON with **`UseDirectConnection": true`**, **`DirectConnectionServerPort": 7777`**
- `CreateDirectNetServer` — **Start server for Direct connection. Port 7777**
- **`gRPC server started. ServerAddress 0.0.0.0:7777`** (game-facing gRPC on the port Envoy uses for TCP, not loopback-only)
- **`LogNet: Created socket for bind address: 0.0.0.0:7777`** and **`IpNetDriver listening on port 7777`**

A **lobby → map** transition may **shut down** one `GameNetDriver` and **start** another; both should show listen on **7777** if the stack is healthy.

**Envoy shows `UF,URX` / `delayed_connect_error:_Connection_refused` to the pod on :7777**  
Usually means **nothing accepted TCP on 7777** at that time — often **`USE_DIRECT_CONNECTION=false`** (invite-only) while **`TCPRoute`** still probes TCP. Fix: enable direct connection for L4 VIP exposure, or stop sending TCP to 7777 from the proxy.

**`kubectl logs` / `kubectl exec` returns `502` to kubelet `:10250`**  
The API server cannot reach the **node kubelet** (e.g. Rancher proxy → worker). **Pod may still be Running**; use another node, **SSH + `crictl logs`**, or repair kubelet on that worker — then tail **`kubectl logs`** or **`R5.log`** as above.
