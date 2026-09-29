{{/*
Expand the chart name.
*/}}
{{- define "application-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "application-stack.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "application-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "application-stack.labels" -}}
helm.sh/chart: {{ include "application-stack.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "application-stack.name" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/*
The configured workload name.
*/}}
{{- define "application-stack.workloadName" -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- default $key $workload.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
The fully qualified workload resource name.
*/}}
{{- define "application-stack.workloadFullname" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- $base := include "application-stack.fullname" $root -}}
{{- $name := include "application-stack.workloadName" (list $root $key $workload) -}}
{{- printf "%s-%s" $base $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels for a workload.
*/}}
{{- define "application-stack.selectorLabels" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
app.kubernetes.io/name: {{ include "application-stack.workloadName" (list $root $key $workload) }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- end -}}

{{/*
Common labels plus workload selector labels.
*/}}
{{- define "application-stack.workloadLabels" -}}
{{- $root := index . 0 -}}
{{ include "application-stack.labels" $root }}
{{ include "application-stack.selectorLabels" . }}
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "application-stack.serviceAccountName" -}}
{{- if ne .Values.serviceAccount.create false -}}
{{- default (include "application-stack.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Oracle ConfigMap name.
*/}}
{{- define "application-stack.oracleConfigMapName" -}}
{{- if .Values.oracle.config.existingConfigMap -}}
{{- .Values.oracle.config.existingConfigMap -}}
{{- else -}}
{{- printf "%s-oracle-config" (include "application-stack.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Oracle Secret name.
*/}}
{{- define "application-stack.oracleSecretName" -}}
{{- if .Values.oracle.secret.existingSecret -}}
{{- .Values.oracle.secret.existingSecret -}}
{{- else -}}
{{- printf "%s-oracle-secret" (include "application-stack.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
