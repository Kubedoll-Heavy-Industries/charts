{{/*
Expand the name of the chart.
*/}}
{{- define "huly.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "huly.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "huly.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "huly.labels" -}}
helm.sh/chart: {{ include "huly.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: huly
{{- end }}

{{/*
Selector labels for a specific component
*/}}
{{- define "huly.selectorLabels" -}}
app.kubernetes.io/name: {{ include "huly.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Resolve image tag for a service (service-specific tag or global)
*/}}
{{- define "huly.imageTag" -}}
{{- . | default $.Values.global.imageTag }}
{{- end }}

{{/*
Secret name
*/}}
{{- define "huly.secretName" -}}
{{- if .Values.existingSecret }}
{{- .Values.existingSecret }}
{{- else }}
{{- include "huly.fullname" . }}-secret
{{- end }}
{{- end }}

{{/*
ConfigMap name
*/}}
{{- define "huly.configMapName" -}}
{{- include "huly.fullname" . }}-config
{{- end }}

{{/*
Pod security context (shared across all services)
*/}}
{{- define "huly.podSecurityContext" -}}
{}
{{- end }}

{{/*
Container security context (shared across all services)
*/}}
{{- define "huly.containerSecurityContext" -}}
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
{{- end }}

{{/*
DB URL from external CockroachDB config
*/}}
{{- define "huly.dbUrl" -}}
{{- $cfg := .Values.externalCockroachdb -}}
{{- printf "postgresql://%s:%s@%s:%v/%s?sslmode=%s" $cfg.username $cfg.password $cfg.host (int $cfg.port) $cfg.database $cfg.sslMode }}
{{- end }}

{{/*
Elasticsearch URL
*/}}
{{- define "huly.elasticUrl" -}}
{{- $cfg := .Values.externalElasticsearch -}}
{{- printf "%s://%s:%v" $cfg.scheme $cfg.host (int $cfg.port) }}
{{- end }}

{{/*
S3 storage config string
*/}}
{{- define "huly.storageConfig" -}}
{{- $cfg := .Values.externalS3 -}}
{{- $endpoint := regexReplaceAll "^https?://" $cfg.endpoint "" -}}
{{- printf "minio|%s?accessKey=%s&secretKey=%s" $endpoint $cfg.accessKey $cfg.secretKey }}
{{- end }}

{{/*
Extract host:port from S3 endpoint URL (strips scheme)
*/}}
{{- define "huly.minioEndpoint" -}}
{{- regexReplaceAll "^https?://" .Values.externalS3.endpoint "" }}
{{- end }}
