# Seafile Helm Chart

Helm-чарт для развёртывания [Seafile](https://www.seafile.com/) — сервера
синхронизации и совместного доступа к файлам — в Kubernetes. Чарт
включает собственные StatefulSet-ы MariaDB и Redis на официальных
образах, Secret с учётными данными, Ingress (опционально) и hook
`helm test`, проверяющий доступность сервера.

Чарт публикуется как OCI-артефакт в GitHub Container Registry:

```
oci://ghcr.io/gera-corp-org/helm-charts/seafile
```

## Требования

- Helm 3.8+ (нужна поддержка OCI-репозиториев).
- Kubernetes 1.19+.
- Доступ на чтение к `ghcr.io/gera-corp-org/helm-charts` (публичный registry,
  анонимный `helm pull`/`helm install` работает без логина).

## Установка

Обязательные значения: `seafile.serverHostname`, `seafile.jwtPrivateKey`,
`seafile.admin.email`, `seafile.admin.password`, `database.rootPassword`,
`database.password`, `cache.password`.

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.0 \
  --namespace seafile --create-namespace \
  --set seafile.serverHostname=seafile.example.com \
  --set seafile.jwtPrivateKey=$(pwgen -s 40 1) \
  --set seafile.admin.email=admin@example.com \
  --set seafile.admin.password=CHANGE-ME \
  --set database.rootPassword=CHANGE-ME \
  --set database.password=CHANGE-ME \
  --set cache.password=CHANGE-ME
```

Для постоянной конфигурации те же значения лучше держать в
`values.yaml` и ставить `--values`:

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.0 \
  --namespace seafile --create-namespace \
  --values my-values.yaml
```

## Секреты

Чарт создаёт до трёх Secret-ов (по одному на компонент), если для
каждого не указан `existingSecret`:

| Secret | Условие создания | Ключи |
|---|---|---|
| `<fullname>` | `seafile.existingSecret` пуст | `admin-email`, `admin-password`, `jwt-private-key` |
| `<fullname>-mariadb` | `database.enabled=true` и `database.existingSecret` пуст | `mariadb-root-password`, `mariadb-password` |
| `<fullname>-redis` | `cache.enabled=true` и `cache.existingSecret` пуст | `redis-password` |

`<fullname>` — имя релиза, либо `<release>-seafile`, если имя релиза
не содержит `seafile` (см. `seafile.fullname` в `_helpers.tpl`).

Если секрет уже существует в кластере (создан отдельно, синковалка
Vault и т. п.), передайте его имя через `existingSecret` — чарт не
будет создавать свой:

```bash
--set seafile.existingSecret=my-seafile-secret \
--set database.existingSecret=my-mariadb-secret \
--set cache.existingSecret=my-redis-secret
```

### bank-vaults / vault-secrets-webhook

Если в кластере работает [vault-secrets-webhook](https://github.com/bank-vaults/vault-secrets-webhook),
значения вида `vault:secret/data/path#KEY` подставляются в переменные
окружения пода на этапе admission — секрет из values.yaml никогда не
попадает в Kubernetes Secret или git в открытом виде. Именно ради
этого сценария в чарте сохранён сырой список `seafile.extraEnv`:

```yaml
seafile:
  extraEnv:
    - name: JWT_PRIVATE_KEY
      value: "vault:secret/data/seafile#JWT_PRIVATE_KEY"
```

`extraEnv` добавляется в контейнер последним и переопределяет
одноимённые переменные, заданные структурированными полями
(`seafile.jwtPrivateKey` и т. д.), поэтому его можно использовать
вместо `existingSecret` для отдельных значений, не отказываясь от
чартового секрета целиком.

## Основные параметры

| Параметр | Описание | По умолчанию |
|---|---|---|
| `image.repository` | Образ Seafile | `docker.io/seafileltd/seafile-mc` |
| `image.tag` | Тег образа Seafile | `""` (берётся `appVersion` чарта) |
| `image.pullPolicy` | Политика подтяжки образа | `IfNotPresent` |
| `imagePullSecrets` | Секреты для приватных registry | `[]` |
| `replicaCount` | Число реплик StatefulSet. `0` останавливает Seafile без удаления релиза и данных | `1` |
| `clusterDomain` | Домен кластера, используется для сборки внутренних FQDN MariaDB/Redis | `cluster.local` |
| `seafile.serverHostname` | Обязателен: FQDN/хост Seafile, без него генерируются нерабочие ссылки | `""` |
| `seafile.protocol` | `http` или `https` | `https` |
| `seafile.timeZone` | Часовой пояс контейнера | `Etc/UTC` |
| `seafile.logToStdout` | Логи Seafile в stdout контейнера | `false` |
| `seafile.admin.email` | E-mail первого администратора | `""` |
| `seafile.admin.password` | Пароль первого администратора | `""` |
| `seafile.jwtPrivateKey` | Ключ для JWT (notification-server, SeaDoc); генерировать `pwgen -s 40 1` | `""` |
| `seafile.webdav.enabled` | Включить WebDAV-эндпоинт | `false` |
| `seafile.existingSecret` | Имя существующего Secret вместо создаваемого чартом | `""` |
| `seafile.extraEnv` | Сырой список `env` для контейнера Seafile, применяется последним | `[]` |
| `seafile.extraEnvFrom` | Сырой список `envFrom` для контейнера Seafile | `[]` |
| `database.enabled` | Разворачивать встроенную MariaDB | `true` |
| `database.host` | Хост внешней БД (обязателен при `enabled=false`) | `""` |
| `database.port` | Порт БД | `3306` |
| `database.user` | Пользователь БД | `seafile` |
| `database.password` | Пароль пользователя БД | `""` |
| `database.rootPassword` | Root-пароль встроенной MariaDB | `""` |
| `database.existingSecret` | Имя существующего Secret с ключами `mariadb-root-password`/`mariadb-password` | `""` |
| `database.names.*` | Имена баз `ccnet`/`seafile`/`seahub` | `ccnet_db`/`seafile_db`/`seahub_db` |
| `database.image.*` | Образ встроенной MariaDB | `docker.io/mariadb:11.4` |
| `database.persistence.*` | PVC встроенной MariaDB (`enabled`, `size`, `storageClass`, `existingClaim`) | `enabled: true`, `size: 8Gi` |
| `database.resources` | Requests/limits контейнера MariaDB | `{}` |
| `cache.provider` | `redis` (встроенный) или `memcached` (только внешний) | `redis` |
| `cache.enabled` | Разворачивать встроенный Redis | `true` |
| `cache.host` | Хост внешнего кэша (обязателен при `enabled=false`) | `""` |
| `cache.port` | Порт кэша | `6379` |
| `cache.password` | Пароль Redis | `""` |
| `cache.existingSecret` | Имя существующего Secret с ключом `redis-password` | `""` |
| `cache.image.*` | Образ встроенного Redis | `docker.io/redis:8-alpine` |
| `cache.resources` | Requests/limits контейнера Redis | `{}` |
| `persistence.enabled` | PVC для данных Seafile | `true` |
| `persistence.size` | Размер PVC | `10Gi` |
| `persistence.storageClass` | StorageClass PVC | `""` |
| `persistence.existingClaim` | Использовать существующий PVC вместо создания нового | `""` |
| `persistence.annotations` | Аннотации PVC (по умолчанию защищает том от удаления) | `{helm.sh/resource-policy: keep}` |
| `service.type` | Тип Service | `ClusterIP` |
| `service.port` | Порт Service | `80` |
| `ingress.enabled` | Создавать Ingress | `false` |
| `ingress.className` | `ingressClassName` | `""` |
| `ingress.annotations` | Дополнительные аннотации Ingress | `{}` |
| `ingress.host` | Хост Ingress (обязателен при `enabled=true`) | `""` |
| `ingress.tls.enabled` | Включить TLS-блок Ingress | `false` |
| `ingress.tls.secretName` | Secret с TLS-сертификатом (обязателен при `tls.enabled=true`) | `""` |
| `ingress.webdav.path` | Путь WebDAV-маршрута Ingress | `/seafdav` |
| `ingress.traefik.buffering` | Создать Traefik Middleware для больших загрузок (см. ниже) | `false` |
| `serviceAccount.create` | Создавать ServiceAccount | `true` |
| `serviceAccount.name` | Имя ServiceAccount (если не `create`, использовать существующий) | `""` |
| `resources` | Requests/limits контейнера Seafile | `{}` |
| `podSecurityContext`, `securityContext` | Контексты безопасности пода/контейнера | `{}` |
| `nodeSelector`, `tolerations`, `affinity` | Планирование пода | `{}` / `[]` / `{}` |
| `startupProbe`, `livenessProbe`, `readinessProbe` | Пробы контейнера Seafile (`/api2/ping/`) | см. `values.yaml` |

## Внешние БД и кэш

Чтобы использовать управляемую MariaDB и Redis вместо встроенных
StatefulSet-ов, отключите `enabled` и укажите хост:

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.0 \
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

`database.rootPassword` при `database.enabled=false` не используется
шаблонами, но остаётся частью Secret-контракта — передайте любое
значение, если не указываете `database.existingSecret`.

## WebDAV

Включается `seafile.webdav.enabled=true`. При включённом Ingress
(`ingress.enabled=true`) чарт автоматически добавляет маршрут на путь
`ingress.webdav.path` (по умолчанию `/seafdav`), указывающий на порт
`8080` сервиса Seafile:

```bash
--set seafile.webdav.enabled=true \
--set ingress.enabled=true \
--set ingress.host=seafile.example.com
```

## Traefik

`ingress.traefik.buffering=true` создаёт Traefik `Middleware` и
подключает её к Ingress аннотацией
`traefik.ingress.kubernetes.io/router.middlewares`. Без буферизации
Traefik по умолчанию ограничивает размер тела запроса, из-за чего
крупные файлы (в первую очередь через WebDAV) не загружаются. Опция
имеет смысл только с `ingress.className=traefik`:

```bash
--set ingress.enabled=true \
--set ingress.host=seafile.example.com \
--set ingress.className=traefik \
--set ingress.traefik.buffering=true
```

## Миграция 0.1.5 → 0.2.0

Зависимости Bitnami (MariaDB, Redis) удалены — их образы больше не
публикуются на Docker Hub, и чарт 0.1.5 с ними не устанавливается.
Интерфейс values изменился:

| 0.1.5 | 0.2.0 |
|---|---|
| `seafile.image: "repo:tag"` | `image.repository` + `image.tag` |
| `seafile.pause: true` | `replicaCount: 0` |
| `seafile.persistence.*` | `persistence.*` |
| `seafile.persistence.storageClassName` | `persistence.storageClass` |
| `seafile.database.hostname` | `database.host` |
| `seafile.database.rootPasswordSecret.{name,key}` | `database.existingSecret` с ключом `mariadb-root-password` |
| `seafile.podSecurityContext` | `podSecurityContext` |
| `seafile.securityContext` | `securityContext` |
| `seafile.environment` (плоский список) | структурированные поля плюс `seafile.extraEnv` |
| `memcached.*` | удалено; встроенного memcached нет, внешний задаётся через `cache.provider: memcached` и `cache.host` |
| `mariadb.*` (Bitnami) | `database.*` |
| `redis.*` (Bitnami) | `cache.*` |
| `ingress.annotations["kubernetes.io/spec.ingressClassName"]` | `ingress.className` |
| `ingress.tls.host` | берётся из `ingress.host` |
| `ingress.tls.secretName` | `ingress.tls.secretName` плюс `ingress.tls.enabled` |
| — | `ingress.enabled`, по умолчанию `false` |

**Ломающее изменение: `ingress.enabled` теперь по умолчанию `false`**,
тогда как в 0.1.5 Ingress создавался всегда. **Апгрейд существующего
релиза без явной установки `ingress.enabled=true` удалит Ingress.**
Перед `helm upgrade` явно передайте:

```bash
--set ingress.enabled=true --set ingress.host=seafile.example.com
```

## Переход с kubectl apply на Helm

Если Seafile в кластере уже развёрнут напрямую манифестами
(`kubectl apply`), существующий PVC с данными можно забрать под
управление Helm, не пересоздавая том — через `persistence.existingClaim`:

```bash
helm install seafile oci://ghcr.io/gera-corp-org/helm-charts/seafile \
  --version 0.2.0 \
  --set seafile.serverHostname=seafile.example.com \
  --set seafile.jwtPrivateKey=$(pwgen -s 40 1) \
  --set seafile.admin.email=admin@example.com \
  --set seafile.admin.password=CHANGE-ME \
  --set database.rootPassword=CHANGE-ME \
  --set database.password=CHANGE-ME \
  --set cache.password=CHANGE-ME \
  --set persistence.existingClaim=seafile-data
```

Чарт не создаёт новый PVC, если указан `existingClaim`, и монтирует
существующий том как есть. По умолчанию `persistence.annotations`
включает `helm.sh/resource-policy: keep` — эта аннотация запрещает
Helm удалять PVC при `helm uninstall` или при пересоздании ресурса,
так что данные остаются в кластере, даже если релиз будет снесён.
Если вы забираете уже существующий PVC (созданный не этим чартом),
проверьте, что аннотация `helm.sh/resource-policy: keep` стоит и на
нём самом — иначе Helm не тронет том, но и её отсутствие ничем не
защищено на будущее.
