# Spark History Server — Helm Chart

Helm chart for deploying [Apache Spark History Server](https://spark.apache.org/docs/latest/monitoring.html#viewing-after-the-fact) on Kubernetes.

## Overview

The Spark History Server provides a web UI for viewing completed Spark application event logs. This chart supports multiple storage backends:

- **S3 / MinIO** — event logs stored in S3-compatible object storage
- **GCS** — Google Cloud Storage
- **PVC** — local persistent volume
- **HDFS** — Hadoop Distributed File System

## Prerequisites

- Kubernetes 1.24+
- Helm 3.x
- A storage backend (S3/MinIO/GCS/PVC) for event logs
- For S3/MinIO: `hadoop-aws` and `aws-java-sdk-bundle` JARs (not included in the default `apache/spark` image — see [S3/MinIO Setup](#s3minio-setup))

## Quick Start

### Install from the packaged chart

```bash
helm install spark-history-server spark-history-server-1.0.0.tgz \
  -f deployed-values.yaml \
  -n default
```

### Install from the extracted chart directory

```bash
helm install spark-history-server ./spark-history-server \
  -f deployed-values.yaml \
  -n default
```

## S3/MinIO Setup

The default `apache/spark:3.5.1` image does not include the Hadoop AWS connector JARs. This chart supports an `extraInitContainers` field to download them at startup.

### 1. Create the S3 credentials secret

```bash
kubectl create secret generic spark-history-s3-creds \
  --from-literal=AWS_ACCESS_KEY_ID=<access-key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret-key>
```

### 2. Create the event log bucket and directory

Event logs must be stored in a **subdirectory** within the bucket (not the bucket root) to avoid a known `hadoop-aws` 3.3.4 S3Guard path resolution issue with MinIO.

```bash
# Using mc (MinIO Client)
mc alias set myminio http://<minio-endpoint> <access-key> <secret-key>
mc mb --ignore-existing myminio/spark-logs
# Create the subdirectory by placing a marker object
echo "placeholder" | mc pipe myminio/spark-logs/events/.keep
```

### 3. Deploy with MinIO values

See `deployed-values.yaml` for a complete working example. Key configuration:

```yaml
sparkConf:
  "spark.history.fs.logDirectory": "s3a://spark-logs/events"

s3:
  enabled: true
  endpoint: "http://minio.default.svc.cluster.local:80"
  pathStyleAccess: true
  credentialsSecret: "spark-history-s3-creds"

extraEnvVars:
  - name: SPARK_DIST_CLASSPATH
    value: "/opt/spark/extra-jars/*"

extraInitContainers:
  - name: download-s3-jars
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        wget -q -O /extra-jars/hadoop-aws-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar &&
        wget -q -O /extra-jars/aws-java-sdk-bundle-1.12.262.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar
    volumeMounts:
      - name: extra-jars
        mountPath: /extra-jars

volumes:
  - name: extra-jars
    emptyDir: {}

volumeMounts:
  - name: extra-jars
    mountPath: /opt/spark/extra-jars
    readOnly: true
```

## Accessing the UI

```bash
kubectl port-forward svc/spark-history-server 18080:18080 -n default
# Open http://localhost:18080
```

## Configuring Spark Jobs

Spark jobs must be configured to write event logs to the same directory:

```bash
spark-submit \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark-logs/events \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio.default.svc.cluster.local:80 \
  --conf spark.hadoop.fs.s3a.access.key=<access-key> \
  --conf spark.hadoop.fs.s3a.secret.key=<secret-key> \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false \
  ...
```

The `hadoop-aws` and `aws-java-sdk-bundle` JARs must also be available on the Spark job classpath. Either:
- Download them into `/opt/spark/jars/` before running `spark-submit`
- Use `--packages org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262` with `--conf spark.jars.ivy=/tmp/.ivy2`

## Chart Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `apache/spark` |
| `image.tag` | Image tag | `3.5.1` (appVersion) |
| `sparkConf` | Spark configuration properties | See `values.yaml` |
| `s3.enabled` | Enable S3 storage backend | `false` |
| `s3.endpoint` | S3 endpoint (for MinIO/Ceph) | `""` |
| `s3.pathStyleAccess` | Use path-style S3 access | `false` |
| `s3.credentialsSecret` | K8s secret with AWS credentials | `""` |
| `gcs.enabled` | Enable GCS storage backend | `false` |
| `persistence.enabled` | Enable PVC storage | `false` |
| `extraInitContainers` | Extra init containers | `[]` |
| `extraEnvVars` | Extra environment variables | `[]` |
| `volumes` | Additional volumes | `[]` |
| `volumeMounts` | Additional volume mounts | `[]` |
| `ingress.enabled` | Enable ingress | `false` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `18080` |
| `resources` | CPU/Memory resources | See `values.yaml` |
| `rbac.create` | Create RBAC resources | `false` |
| `autoscaling.enabled` | Enable HPA | `false` |

## Known Issues

- **hadoop-aws 3.3.4 + MinIO**: Using the bucket root as `spark.history.fs.logDirectory` (e.g., `s3a://bucket/`) triggers a `path must be absolute` error in S3Guard's `PathMetadata`. Use a subdirectory path instead (e.g., `s3a://bucket/events`).
- **hadoop-aws version must match**: The `hadoop-aws` JAR version must match the Hadoop version bundled in the Spark image (3.3.4 for `apache/spark:3.5.1`). Using a newer minor version (e.g., 3.3.6) causes `NoClassDefFoundError`.
