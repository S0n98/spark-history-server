{{/*
Expand the name of the chart.
*/}}
{{- define "spark-history-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
*/}}
{{- define "spark-history-server.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart label.
*/}}
{{- define "spark-history-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "spark-history-server.labels" -}}
helm.sh/chart: {{ include "spark-history-server.chart" . }}
{{ include "spark-history-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "spark-history-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spark-history-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "spark-history-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "spark-history-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Spark configuration — merged from .Values.sparkConf + storage-specific keys.
*/}}
{{- define "spark-history-server.sparkConf" -}}
{{- $conf := dict }}
{{- range $k, $v := .Values.sparkConf }}
{{- $_ := set $conf $k $v }}
{{- end }}
{{- if .Values.s3.enabled }}
  {{- $_ := set $conf "spark.hadoop.fs.s3a.impl" "org.apache.hadoop.fs.s3a.S3AFileSystem" }}
  {{- if .Values.s3.endpoint }}
  {{- $_ = set $conf "spark.hadoop.fs.s3a.endpoint" .Values.s3.endpoint }}
  {{- end }}
  {{- if .Values.s3.pathStyleAccess }}
  {{- $_ = set $conf "spark.hadoop.fs.s3a.path.style.access" "true" }}
  {{- end }}
  {{- range $k, $v := .Values.s3.extraConf }}
  {{- $_ = set $conf $k $v }}
  {{- end }}
{{- end }}
{{- $lines := list }}
{{- range $k, $v := $conf }}
{{- $lines = append $lines (printf "%s=%s" $k $v) }}
{{- end }}
{{- $lines | join "\n" }}
{{- end }}

{{/*
Hadoop configuration (core-site.xml properties).
*/}}
{{- define "spark-history-server.hadoopConf" -}}
{{- $lines := list }}
{{- range $k, $v := .Values.hadoopConf }}
{{- $lines = append $lines (printf "%s=%s" $k $v) }}
{{- end }}
{{- $lines | join "\n" }}
{{- end }}
