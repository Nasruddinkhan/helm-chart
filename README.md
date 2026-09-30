# application-stack Helm Chart

This repository contains the Helm chart and GitOps manifests for deploying the application stack.

This chart deploys two configurable workloads:

- `application`
- `config-service`

It also manages shared Oracle database configuration for backend services.

All Kubernetes YAML is managed through `values.yaml`. Change image repositories, tags, environment variables, config data, secrets, services, ingress, probes, resources, autoscaling, scheduling, and extra volumes there.

## Full Documentation

Read the full chart guide here:

- [docs/helm-chart-guide.md](docs/helm-chart-guide.md)

The guide explains the chart structure, workload configuration, Oracle setup, Helm install commands, Argo CD GitOps flow, and troubleshooting steps.

## Install

```bash
helm install application-stack .
```

## Render YAML locally

```bash
helm template application-stack .
```

## Common overrides

```bash
helm upgrade --install application-stack . \
  --set workloads.application.image.repository=docker.io/nasruddinkhan/application \
  --set workloads.application.image.tag=1.0.0 \
  --set workloads.configService.image.repository=docker.io/nasruddinkhan/config-service \
  --set workloads.configService.image.tag=1.0.0
```

Docker Hub image repository names are lowercase, so this chart uses `nasruddinkhan` in image references.

## Oracle

Oracle connection settings are managed under `oracle` in `values.yaml`.

Backend workloads opt in with:

```yaml
workloads:
  application:
    oracle:
      enabled: true
```

The chart creates:

- Oracle ConfigMap: non-secret settings like host, port, service name, and JDBC URL
- Oracle Secret: username and password

For production GitOps, `environments/prod/values.yaml` is configured to use an existing Kubernetes Secret named `oracle-credentials` instead of committing real credentials to Git:

```bash
kubectl create secret generic oracle-credentials \
  --namespace application-prod \
  --from-literal=ORACLE_USERNAME=app_user \
  --from-literal=ORACLE_PASSWORD='replace-me'
```

## Secrets

Enable a workload secret in `values.yaml`:

```yaml
workloads:
  application:
    secret:
      enabled: true
      stringData:
        DATABASE_PASSWORD: change-me
```

For production, prefer an encrypted values workflow or an external secret operator rather than committing real secret values.

## GitOps

This repo includes Argo CD GitOps manifests in `gitops/argocd`.

Argo CD is the recommended GitOps option for this chart because it works directly with Helm, tracks drift, supports automated sync, and gives you a clear UI for rollout status.

Bootstrap Argo CD with:

```bash
kubectl apply -f gitops/argocd/project.yaml
kubectl apply -f gitops/argocd/application-dev.yaml
```

Production is also available:

```bash
kubectl apply -f gitops/argocd/application-prod.yaml
```

Environment-specific values live in:

- `environments/dev/values.yaml`
- `environments/prod/values.yaml`
