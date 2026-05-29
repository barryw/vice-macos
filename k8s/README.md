# mac VICE Kubernetes Deployment

These manifests publish the static mac VICE website at:

- `https://macvice.com`
- `https://www.macvice.com`

They assume:

- an image named `ghcr.io/barryw/macvice-website`
- an nginx-compatible ingress class named `nginx`
- cert-manager with a `ClusterIssuer` named `letsencrypt-production`

Patch `k8s/ingress.yaml` if your cluster uses a different ingress class or TLS
issuer.

## Build

Build the website container from the `website/` directory:

```sh
docker build -f website/Containerfile -t ghcr.io/barryw/macvice-website:latest website
docker push ghcr.io/barryw/macvice-website:latest
```

For a release tag:

```sh
docker build -f website/Containerfile -t ghcr.io/barryw/macvice-website:3.10.0-816fb9c-1 website
docker push ghcr.io/barryw/macvice-website:3.10.0-816fb9c-1
kustomize edit set image ghcr.io/barryw/macvice-website=ghcr.io/barryw/macvice-website:3.10.0-816fb9c-1
```

## Deploy

```sh
kubectl apply -k k8s
kubectl -n macvice rollout status deployment/macvice-website
kubectl -n macvice get ingress macvice-website
```

Point DNS for `macvice.com` and `www.macvice.com` at the ingress controller's
external address. cert-manager should create the `macvice-com-tls` secret after
DNS resolves to the cluster.

## Woodpecker

`.woodpecker/website.yaml` watches `website/**`, `k8s/**`, and its own pipeline
file on `macos/native-metal`.

On push it:

1. validates the HTML, JavaScript, screenshot script, and Kubernetes manifests
2. builds `ghcr.io/barryw/macvice-website:<short-sha>`
3. pushes the short-SHA tag and `latest`
4. applies `k8s/`
5. updates the deployment to the short-SHA image and waits for rollout

The local Woodpecker runner must have:

- Docker access for `docker build`, `docker push`, and `docker login`
- `kubectl` configured for the target local cluster
- the existing `github_token` secret with permission to push to GHCR
