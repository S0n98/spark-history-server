# CLAUDE.md

## Project Overview

Helm chart for deploying Apache Spark History Server on Kubernetes. The History Server is a read-only web UI for viewing completed Spark application event logs.

## Repository Structure

```
spark-history-server/       # Helm chart
  Chart.yaml                # Chart metadata (version, appVersion)
  values.yaml               # Default values
  templates/
    _helpers.tpl             # Template helpers (name, labels, sparkConf)
    deployment.yaml          # Main workload
    configmap.yaml           # spark-defaults.conf + optional core-site.xml
    service.yaml             # ClusterIP service for the UI (port 18080)
    serviceaccount.yaml      # Optional ServiceAccount (for IRSA/Workload Identity)
    ingress.yaml             # Optional Ingress
    pvc.yaml                 # Optional PVC for local event log storage
    NOTES.txt                # Post-install instructions
  ci/
    s3-values.yaml           # CI test values for S3/IRSA
    pvc-values.yaml          # CI test values for PVC storage
docker/
  Dockerfile                 # Custom image with hadoop-aws JARs for S3/MinIO
```

## Storage Backends

The chart supports S3/MinIO, GCS, PVC, and HDFS. Storage is configured via `sparkConf` + the `s3`, `gcs`, or `persistence` values sections. Only one backend should be enabled at a time.

## Key Design Decisions

- `automountServiceAccountToken: false` on both the ServiceAccount and Deployment — the History Server does not interact with the Kubernetes API.
- No RBAC (ClusterRole/ClusterRoleBinding) — unnecessary for the same reason.
- No HPA — the History Server is a single-instance read-only UI; horizontal scaling adds no value.
- The `readOnlyRootFilesystem: true` security context requires a `/tmp` emptyDir volume for JVM temp files.

## Build & Package

```bash
# Package the chart
helm package spark-history-server/

# Lint
helm lint spark-history-server/

# Template render (dry-run)
helm template test spark-history-server/ -f spark-history-server/ci/s3-values.yaml
helm template test spark-history-server/ -f spark-history-server/ci/pvc-values.yaml
```

## Versioning

- Chart version is in `spark-history-server/Chart.yaml` (`version` field).
- Bump `version` for chart changes, `appVersion` for upstream Spark version changes.
- After version bump, re-run `helm package` and remove the old `.tgz`.
