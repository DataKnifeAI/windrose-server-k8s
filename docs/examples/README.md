# Kubernetes examples (reference)

| File | Purpose |
|------|---------|
| `clusterip-envoy-backend.example.yaml` | **ClusterIP** `Service` mirroring game ports for **Envoy** to target (same selector as `windrose-server` Deployment). |
| `envoyproxy-kube-vip.example.yaml` | **EnvoyProxy** for **kube-vip** (`loadBalancerIP` + `externalTrafficPolicy: Cluster`). Replace `LOAD_BALANCER_IP`; must match `Gateway.spec.addresses`. |
| `gateway-tcp-udp.example.yaml` | **Gateway** (with **`infrastructure.parametersRef`**) + **TCPRoute** / **UDPRoute** for **7777** TCP+UDP and **8780** TCP (Windrose+). Use a **dedicated VIP** if another game already uses TCP 7777 on the same Gateway. |

Apply **`deploy/`** for the app. Envoy exposure: **`kubectl apply -k deploy/envoy/`** (see **`../deploy/envoy/`**). **`docs/examples/`** here uses placeholders for forks.
