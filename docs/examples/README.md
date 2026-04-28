# Kubernetes examples (reference)

| File | Purpose |
|------|---------|
| `clusterip-envoy-backend.example.yaml` | **ClusterIP** `Service` mirroring game ports for **Envoy** to target (same selector as `windrose-server` Deployment). |
| `gateway-tcp-udp.example.yaml` | **Gateway** + **TCPRoute** / **UDPRoute** for **7777** TCP+UDP and **8780** TCP (Windrose+). Use a **dedicated VIP** if another game already uses TCP 7777 on the same Gateway. |

Apply the app with **`kubectl apply -k deploy/`**. These snippets are for **platform** integration (Envoy Gateway, kube-vip). Canonical manifests for DataKnife: **`https://github.com/DataKnifeAI/gitops-tools`**.
