# Helm Chart Guide

This document explains how this Helm chart works and how to deploy the full application stack.

## What This Chart Deploys

The chart deploys three Kubernetes workloads:

- `config-service`: configuration service, exposed inside the cluster on port `8888`
- `application`: backend application, exposed inside the cluster on port `80`
- `ui`: frontend UI, exposed inside the cluster on port `80`

The chart also manages shared Oracle database settings:

- Oracle ConfigMap for non-secret values such as host, port, service name, and JDBC URL
- Oracle Secret for username and password

By default, only `application` consumes Oracle settings. `config-service` and `ui` do not receive Oracle environment variables unless you enable them.

## Repository Layout

```text
.
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── _workload.tpl
│   ├── application/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── hpa.yaml
│   │   ├── ingress.yaml
│   │   ├── secret.yaml
│   │   └── service.yaml
│   ├── config-service/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── hpa.yaml
│   │   ├── ingress.yaml
│   │   ├── secret.yaml
│   │   └── service.yaml
│   ├── ui/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── hpa.yaml
│   │   ├── ingress.yaml
│   │   ├── secret.yaml
│   │   └── service.yaml
│   ├── oracle/
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   └── common/
│       └── serviceaccount.yaml
├── environments/
│   ├── dev/values.yaml
│   └── prod/values.yaml
└── gitops/
    └── argocd/
        ├── project.yaml
        ├── application-dev.yaml
        └── application-prod.yaml
```

## Important Files

| File | Purpose |
| --- | --- |
| `Chart.yaml` | Helm chart metadata such as chart name and version |
| `values.yaml` | Main default configuration for all workloads |
| `templates/_helpers.tpl` | Shared naming and label helpers |
| `templates/_workload.tpl` | Shared workload rendering logic used by each project folder |
| `templates/application/*.yaml` | Kubernetes resources for the backend application |
| `templates/config-service/*.yaml` | Kubernetes resources for the config service |
| `templates/ui/*.yaml` | Kubernetes resources for the UI |
| `templates/oracle/*.yaml` | Shared Oracle ConfigMap and Secret resources |
| `templates/common/serviceaccount.yaml` | Shared ServiceAccount resource |
| `environments/dev/values.yaml` | Dev overrides for GitOps or Helm installs |
| `environments/prod/values.yaml` | Prod overrides for GitOps or Helm installs |
| `gitops/argocd/*.yaml` | Argo CD GitOps resources |

Each component folder has its own YAML files so the chart is easy to browse. The files call reusable templates from `_workload.tpl`, which keeps the generated resources consistent across `application`, `config-service`, and `ui`.

## How Values Are Organized

All applications are configured under `workloads`.

```yaml
workloads:
  application:
    enabled: true
  configService:
    enabled: true
  ui:
    enabled: true
```

Each workload supports the same common sections:

| Section | Purpose |
| --- | --- |
| `enabled` | Turns the workload on or off |
| `replicaCount` | Number of Pods when autoscaling is disabled |
| `image` | Container image repository, tag, and pull policy |
| `containerPort` | Port exposed by the container |
| `env` | Explicit environment variables |
| `envFrom` | Extra ConfigMap or Secret references |
| `config` | Creates workload ConfigMap and optionally loads it as env vars |
| `secret` | Creates optional workload Secret and loads it as env vars |
| `oracle` | Controls whether the workload receives Oracle env vars |
| `service` | Kubernetes Service settings |
| `ingress` | Optional Ingress settings |
| `probes` | Liveness and readiness probes |
| `resources` | CPU and memory requests/limits |
| `autoscaling` | HorizontalPodAutoscaler settings |
| `nodeSelector`, `tolerations`, `affinity` | Scheduling controls |

## Image Configuration

Update image repositories and tags before deploying:

```yaml
workloads:
  application:
    image:
      repository: docker.io/nasruddinkhan/application
      tag: 1.0.0

  configService:
    image:
      repository: docker.io/nasruddinkhan/config-service
      tag: 1.0.0

  ui:
    image:
      repository: docker.io/nasruddinkhan/ui
      tag: 1.0.0
```

Docker Hub image repository names are lowercase. Use `nasruddinkhan` in image paths even if the account name is written as `Nasruddinkhan`.

## Oracle Configuration

Oracle settings are configured globally under `oracle`.

```yaml
oracle:
  enabled: true
  config:
    data:
      ORACLE_HOST: oracle.example.com
      ORACLE_PORT: "1521"
      ORACLE_SERVICE_NAME: ORCLPDB1
      ORACLE_JDBC_URL: jdbc:oracle:thin:@//oracle.example.com:1521/ORCLPDB1
  secret:
    stringData:
      ORACLE_USERNAME: app_user
      ORACLE_PASSWORD: change-me
```

To give a workload Oracle environment variables, enable Oracle on that workload:

```yaml
workloads:
  application:
    oracle:
      enabled: true
```

The workload receives these environment variables from the Oracle ConfigMap and Secret:

- `ORACLE_HOST`
- `ORACLE_PORT`
- `ORACLE_SERVICE_NAME`
- `ORACLE_JDBC_URL`
- `ORACLE_USERNAME`
- `ORACLE_PASSWORD`

## Production Oracle Secret

Do not commit real Oracle passwords to Git.

The production values file is configured to use an existing Kubernetes Secret:

```yaml
oracle:
  secret:
    create: false
    existingSecret: oracle-credentials
```

Create that Secret before syncing production:

```bash
kubectl create secret generic oracle-credentials \
  --namespace application-prod \
  --from-literal=ORACLE_USERNAME=app_user \
  --from-literal=ORACLE_PASSWORD='replace-me'
```

## Installing With Helm

Install with default values:

```bash
helm install application-stack .
```

Install with dev values:

```bash
helm upgrade --install application-stack . \
  --namespace application-dev \
  --create-namespace \
  -f environments/dev/values.yaml
```

Install with prod values:

```bash
helm upgrade --install application-stack . \
  --namespace application-prod \
  --create-namespace \
  -f environments/prod/values.yaml
```

Render Kubernetes YAML without installing:

```bash
helm template application-stack . -f environments/dev/values.yaml
```

## Deploying With Argo CD

The repo includes Argo CD manifests under `gitops/argocd`.

Apply the Argo CD project:

```bash
kubectl apply -f gitops/argocd/project.yaml
```

Apply dev:

```bash
kubectl apply -f gitops/argocd/application-dev.yaml
```

Apply prod:

```bash
kubectl apply -f gitops/argocd/application-prod.yaml
```

Argo CD reads this Git repository:

```text
git@github.com:Nasruddinkhan/helm-chart.git
```

The Argo CD applications use:

- `environments/dev/values.yaml` for dev
- `environments/prod/values.yaml` for prod

## Common Changes

### Change Replica Count

```yaml
workloads:
  application:
    replicaCount: 2
```

### Enable Ingress

```yaml
workloads:
  ui:
    ingress:
      enabled: true
      className: nginx
      hosts:
        - host: ui.example.com
          paths:
            - path: /
              pathType: Prefix
```

### Add Resource Limits

```yaml
workloads:
  application:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

### Enable Autoscaling

```yaml
workloads:
  application:
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 5
      targetCPUUtilizationPercentage: 80
```

### Disable a Workload

```yaml
workloads:
  ui:
    enabled: false
```

## Generated Resource Names

When installed with release name `application-stack`, the main resources are:

| Workload | Deployment | Service |
| --- | --- | --- |
| application | `application-stack-application` | `application-stack-application` |
| config-service | `application-stack-config-service` | `application-stack-config-service` |
| ui | `application-stack-ui` | `application-stack-ui` |

The Oracle resources are:

| Resource | Name |
| --- | --- |
| ConfigMap | `application-stack-oracle-config` |
| Secret | `application-stack-oracle-secret` by default, or `oracle-credentials` in prod |

## Troubleshooting

Render the chart first:

```bash
helm template application-stack . -f environments/dev/values.yaml
```

Check deployed Pods:

```bash
kubectl get pods -n application-dev
```

Check Services:

```bash
kubectl get svc -n application-dev
```

Check application logs:

```bash
kubectl logs -n application-dev deploy/application-stack-application
```

Check whether Oracle variables reached the application Pod:

```bash
kubectl exec -n application-dev deploy/application-stack-application -- env | grep ORACLE
```

Check Argo CD sync status:

```bash
kubectl get applications -n argocd
```

## Deployment Checklist

Before deploying, confirm:

- Image repositories are correct for `application`, `config-service`, and `ui`
- Image tags match the version you want to deploy
- Oracle host, port, service name, and JDBC URL are correct
- Production Oracle credentials are stored in a Kubernetes Secret
- Ingress hostnames are correct if ingress is enabled
- Resource requests and limits are suitable for the cluster
- Argo CD can access `git@github.com:Nasruddinkhan/helm-chart.git`
