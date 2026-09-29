# Argo CD GitOps

This directory contains Argo CD resources for deploying the Helm chart from:

```text
git@github.com:Nasruddinkhan/helm-chart.git
```

## Recommended workflow

1. Update the chart or environment values in Git.
2. Commit and push to `main`.
3. Argo CD detects the change and syncs the cluster.

## Bootstrap

Apply the Argo CD project first:

```bash
kubectl apply -f gitops/argocd/project.yaml
```

Then apply the environment application you want:

```bash
kubectl apply -f gitops/argocd/application-dev.yaml
kubectl apply -f gitops/argocd/application-prod.yaml
```

## Dev vs prod

- `dev` uses automated prune and self-heal.
- `prod` uses automated self-heal but disables prune by default, which is safer until you are comfortable with the deployment flow.

Change the image repositories, tags, hostnames, secrets, and resource sizing in:

- `environments/dev/values.yaml`
- `environments/prod/values.yaml`
