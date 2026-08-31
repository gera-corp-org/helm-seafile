# Seafile Helm Chart

A Helm chart for deploying [Seafile](https://www.seafile.com/) — a file
sync and share server — on Kubernetes. The chart includes its own
MariaDB and Redis StatefulSets built on official images, a Secret for
credentials, an optional Ingress, and a `helm test` hook that checks
the server is reachable.

The chart is published as an OCI artifact on GitHub Container Registry:

```
oci://ghcr.io/gera-corp-org/helm-charts/seafile
```

## Requirements

- Helm 3.8+ (OCI registry support is required).
- Kubernetes 1.19+.
- Read access to `ghcr.io/gera-corp-org/helm-charts` (a public registry —
  anonymous `helm pull`/`helm install` works without logging in).

## Installation

Required values: `seafile.serverHostname`, `seafile.jwtPrivateKey`,
`seafile.admin.email`, `seafile.admin.password`, `database.rootPassword`,
`database.password`, `cache.password`.

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.1 \
  --namespace seafile --create-namespace \
  --set seafile.serverHostname=seafile.example.com \
  --set seafile.jwtPrivateKey=$(pwgen -s 40 1) \
  --set seafile.admin.email=admin@example.com \
  --set seafile.admin.password=CHANGE-ME \
  --set database.rootPassword=CHANGE-ME \
  --set database.password=CHANGE-ME \
  --set cache.password=CHANGE-ME
```

For a persistent configuration, keep these same values in
`values.yaml` and pass `--values`:

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.1 \
  --namespace seafile --create-namespace \
  --values my-values.yaml
```

## Secrets

The chart creates up to three Secrets (one per component), unless
`existingSecret` is set for that component:

| Secret | Created when | Keys |
|---|---|---|
| `<fullname>` | `seafile.existingSecret` is empty | `admin-email`, `admin-password`, `jwt-private-key` |
| `<fullname>-mariadb` | `database.existingSecret` is empty | `mariadb-root-password`, `mariadb-password` |
| `<fullname>-redis` | `cache.provider=redis` and `cache.existingSecret` is empty | `redis-password` |

The MariaDB Secret is created regardless of `database.enabled`: the
Seafile pod always references both keys, even with an external
database (see "External database and cache" below) — without this
Secret the pod won't start. The Redis Secret is created only for
`cache.provider=redis` (including an external Redis with no built-in
StatefulSet); with `provider=memcached` it isn't needed and isn't
created.

`<fullname>` is the release name, or `<release>-seafile` if the
release name doesn't contain `seafile` (see `seafile.fullname` in
`_helpers.tpl`).

If a Secret already exists in the cluster (created separately, by a
Vault sync tool, etc.), pass its name via `existingSecret` — the chart
won't create its own:

```bash
--set seafile.existingSecret=my-seafile-secret \
--set database.existingSecret=my-mariadb-secret \
--set cache.existingSecret=my-redis-secret
```

### bank-vaults / vault-secrets-webhook

If [vault-secrets-webhook](https://github.com/bank-vaults/vault-secrets-webhook)
is running in the cluster, values shaped like `vault:secret/data/path#KEY`
get substituted into the pod's environment variables at the admission
stage — the secret from values.yaml never ends up in a Kubernetes
Secret or in git in plain text. The chart keeps a raw `seafile.extraEnv`
list specifically for this scenario:

```yaml
seafile:
  extraEnv:
    - name: JWT_PRIVATE_KEY
      value: "vault:secret/data/seafile#JWT_PRIVATE_KEY"
```

`extraEnv` is appended to the container last and overrides any
variables of the same name set through the structured fields
(`seafile.jwtPrivateKey`, etc.), so it can be used instead of
`existingSecret` for individual values without giving up the chart's
Secret entirely.

## Main parameters

| Parameter | Description | Default |
|---|---|---|
| `image.repository` | Seafile image | `docker.io/seafileltd/seafile-mc` |
| `image.tag` | Seafile image tag | `""` (uses the chart's `appVersion`) |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Secrets for private registries | `[]` |
| `replicaCount` | Number of StatefulSet replicas. `0` stops Seafile without deleting the release or its data | `1` |
| `clusterDomain` | Cluster domain, used to build internal MariaDB/Redis FQDNs | `cluster.local` |
| `nameOverride` | Override the chart's short name in templates | `""` |
| `fullnameOverride` | Override the full resource name (`<fullname>`) entirely | `""` |
| `seafile.serverHostname` | Required: Seafile's FQDN/hostname; without it, generated links are broken | `""` |
| `seafile.protocol` | `http` or `https` | `https` |
| `seafile.timeZone` | Container timezone | `Etc/UTC` |
| `seafile.logToStdout` | Send Seafile logs to the container's stdout | `false` |
| `seafile.admin.email` | Email of the first admin account | `""` |
| `seafile.admin.password` | Password of the first admin account | `""` |
| `seafile.jwtPrivateKey` | JWT key (notification-server, SeaDoc); generate with `pwgen -s 40 1` | `""` |
| `seafile.webdav.enabled` | Enable the WebDAV endpoint | `false` |
| `seafile.existingSecret` | Name of an existing Secret to use instead of the one the chart creates | `""` |
| `seafile.extraEnv` | Raw `env` list for the Seafile container, applied last | `[]` |
| `seafile.extraEnvFrom` | Raw `envFrom` list for the Seafile container | `[]` |
| `database.enabled` | Deploy the built-in MariaDB | `true` |
| `database.host` | External database host (required when `enabled=false`) | `""` |
| `database.port` | Database port | `3306` |
| `database.user` | Database user | `seafile` |
| `database.password` | Database user password | `""` |
| `database.rootPassword` | Root password for the built-in MariaDB | `""` |
| `database.existingSecret` | Name of an existing Secret with the `mariadb-root-password`/`mariadb-password` keys | `""` |
| `database.names.*` | Names of the `ccnet`/`seafile`/`seahub` databases | `ccnet_db`/`seafile_db`/`seahub_db` |
| `database.image.*` | Built-in MariaDB image | `docker.io/mariadb:11.4` |
| `database.persistence.*` | Built-in MariaDB PVC (`enabled`, `size`, `storageClass`, `existingClaim`, `subPath`) | `enabled: true`, `size: 8Gi` |
| `database.resources` | Requests/limits for the MariaDB container | `{}` |
| `cache.provider` | `redis` (built-in) or `memcached` (external only) | `redis` |
| `cache.enabled` | Deploy the built-in Redis | `true` |
| `cache.host` | External cache host (required when `enabled=false`) | `""` |
| `cache.port` | Cache port | `6379` |
| `cache.password` | Redis password | `""` |
| `cache.existingSecret` | Name of an existing Secret with the `redis-password` key | `""` |
| `cache.image.*` | Built-in Redis image | `docker.io/redis:8-alpine` |
| `cache.resources` | Requests/limits for the Redis container | `{}` |
| `persistence.enabled` | PVC for Seafile data | `true` |
| `persistence.size` | PVC size | `10Gi` |
| `persistence.storageClass` | PVC StorageClass | `""` |
| `persistence.existingClaim` | Use an existing PVC instead of creating a new one | `""` |
| `persistence.annotations` | PVC annotations (defaults to protecting the volume from deletion) | `{helm.sh/resource-policy: keep}` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Create an Ingress | `false` |
| `ingress.className` | `ingressClassName` | `""` |
| `ingress.annotations` | Extra Ingress annotations | `{}` |
| `ingress.host` | Ingress host (required when `enabled=true`) | `""` |
| `ingress.tls.enabled` | Enable the Ingress TLS block | `false` |
| `ingress.tls.secretName` | Secret with the TLS certificate (required when `tls.enabled=true`) | `""` |
| `ingress.webdav.path` | Path for the Ingress WebDAV route | `/seafdav` |
| `ingress.traefik.buffering` | Create a Traefik Middleware for large uploads (see below) | `false` |
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name (if not `create`, use an existing one) | `""` |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| `resources` | Requests/limits for the Seafile container | `{}` |
| `podAnnotations` | Seafile pod annotations | `{}` |
| `podLabels` | Extra labels for the Seafile pod | `{}` |
| `podSecurityContext`, `securityContext` | Pod/container security contexts | `{}` |
| `nodeSelector`, `tolerations`, `affinity` | Pod scheduling | `{}` / `[]` / `{}` |
| `startupProbe`, `livenessProbe`, `readinessProbe` | Seafile container probes (`/api2/ping/`) | see `values.yaml` |

## Adopting a volume from another chart

The official MariaDB image keeps its data directly in `/var/lib/mysql`,
while some other charts — the Bitnami one among them — keep it under a
`data` subdirectory of the volume. Mounting such a volume at the root
makes the official image see no database, initialize a fresh one beside
the old files, and reject every existing login with `Access denied`. The
old data is untouched, just invisible.

`database.persistence.subPath` mounts a subdirectory as the data
directory instead, which leaves the volume layout as it was:

```bash
--set database.persistence.existingClaim=data-seafile-mariadb-0 \
--set database.persistence.subPath=data
```

Check what is actually on the volume before setting this — if the volume
root already holds `ibdata1` and a `mysql/` directory, it is a plain data
directory and `subPath` must stay empty.

## External database and cache

To use a managed MariaDB and Redis instead of the built-in
StatefulSets, disable `enabled` and set the host:

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.1 \
  --set seafile.serverHostname=seafile.example.com \
  --set seafile.jwtPrivateKey=$(pwgen -s 40 1) \
  --set seafile.admin.email=admin@example.com \
  --set seafile.admin.password=CHANGE-ME \
  --set database.enabled=false \
  --set database.host=mariadb.example.com \
  --set database.password=CHANGE-ME \
  --set database.rootPassword=unused \
  --set cache.enabled=false \
  --set cache.host=redis.example.com \
  --set cache.password=CHANGE-ME
```

`database.rootPassword` isn't used by the templates when
`database.enabled=false`, but it's still part of the Secret contract —
pass any value if you're not setting `database.existingSecret`.

## WebDAV

**Requires one manual step — the chart cannot enable WebDAV by
itself.**

`seafile.webdav.enabled=true` opens port `8080` on the container and
the Service, and adds a route on the `ingress.webdav.path` path
(`/seafdav` by default) when Ingress is enabled:

```bash
--set seafile.webdav.enabled=true \
--set ingress.enabled=true \
--set ingress.host=seafile.example.com
```

That's enough on the networking side, but not for Seafile itself: it
only reads the enable flag from `seafdav.conf`, and
`setup-seafile-mysql.py` inside the image hardcodes `enabled = false`
there. There's no environment variable for this — [adding one was
proposed back in 2019](https://github.com/haiwen/seafile-docker/pull/187)
specifically for Kubernetes, but the PR was never merged. The
[Seafile documentation](https://manual.seafile.com/13.0/extension/webdav/)
says to edit the file and restart the server.

Until the flag is set, `/seafdav` returns `502`. To enable it:

```bash
kubectl exec -n seafile seafile-0 -- \
  sed -i 's/^enabled = false/enabled = true/' /shared/seafile/conf/seafdav.conf
kubectl rollout restart sts/seafile -n seafile
```

Verify (success is `207 Multi-Status`):

```bash
curl -u 'admin@example.com:PASSWORD' -X PROPFIND -H 'Depth: 0' \
  -o /dev/null -w '%{http_code}\n' https://seafile.example.com/seafdav/
```

The edit lives in the PVC and survives pod restarts, but won't survive
the volume being recreated. Large uploads over WebDAV behind Traefik
also need the section below.

## Traefik

`ingress.traefik.buffering=true` creates a Traefik `Middleware` and
attaches it to the Ingress via the
`traefik.ingress.kubernetes.io/router.middlewares` annotation. Without
buffering, Traefik's default request body size limit blocks large file
uploads (WebDAV in particular). This option only makes sense with
`ingress.className=traefik`:

```bash
--set ingress.enabled=true \
--set ingress.host=seafile.example.com \
--set ingress.className=traefik \
--set ingress.traefik.buffering=true
```

## Migrating from 0.1.5 to 0.2.0

The Bitnami dependencies (MariaDB, Redis) have been removed — their
images are no longer published on Docker Hub, so chart 0.1.5 no longer
installs with them. The values interface has changed:

| 0.1.5 | 0.2.0 |
|---|---|
| `seafile.image: "repo:tag"` | `image.repository` + `image.tag` |
| `seafile.pause: true` | `replicaCount: 0` |
| `seafile.persistence.*` | `persistence.*` |
| `seafile.persistence.storageClassName` | `persistence.storageClass` |
| `seafile.database.hostname` | `database.host` |
| `seafile.database.rootPasswordSecret.{name,key}` | `database.existingSecret` with the `mariadb-root-password` key |
| `seafile.podSecurityContext` | `podSecurityContext` |
| `seafile.securityContext` | `securityContext` |
| `seafile.environment` (flat list) | structured fields plus `seafile.extraEnv` |
| `memcached.*` | removed; there's no built-in memcached — external memcached is configured via `cache.provider: memcached` and `cache.host` |
| `mariadb.*` (Bitnami) | `database.*` |
| `redis.*` (Bitnami) | `cache.*` |
| `ingress.annotations["kubernetes.io/spec.ingressClassName"]` | `ingress.className` |
| `ingress.tls.host` | taken from `ingress.host` |
| `ingress.tls.secretName` | `ingress.tls.secretName` plus `ingress.tls.enabled` |
| — | `ingress.enabled`, defaults to `false` |

**Breaking change: `ingress.enabled` now defaults to `false`**,
whereas in 0.1.5 the Ingress was always created. **Upgrading an
existing release without explicitly setting `ingress.enabled=true`
will delete the Ingress.** Before `helm upgrade`, explicitly pass:

```bash
--set ingress.enabled=true --set ingress.host=seafile.example.com
```

## Migrating from kubectl apply to Helm

If Seafile is already deployed in the cluster directly via manifests
(`kubectl apply`), the existing data PVC can be brought under Helm
management without recreating the volume — via
`persistence.existingClaim`:

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.1 \
  --set seafile.serverHostname=seafile.example.com \
  --set seafile.jwtPrivateKey=$(pwgen -s 40 1) \
  --set seafile.admin.email=admin@example.com \
  --set seafile.admin.password=CHANGE-ME \
  --set database.rootPassword=CHANGE-ME \
  --set database.password=CHANGE-ME \
  --set cache.password=CHANGE-ME \
  --set persistence.existingClaim=seafile-data
```

The chart doesn't create a new PVC when `existingClaim` is set, and
mounts the existing volume as-is. By default, `persistence.annotations`
includes `helm.sh/resource-policy: keep` — this annotation stops Helm
from deleting the PVC on `helm uninstall` or when the resource is
recreated, so the data stays in the cluster even if the release is
torn down. If you're adopting a PVC that already exists (created
outside this chart), verify that the `helm.sh/resource-policy: keep`
annotation is present on it as well — without it, Helm won't
necessarily touch the volume today, but nothing protects it from
deletion in the future.
