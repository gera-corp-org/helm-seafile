{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "seafile.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "seafile.fullname" -}}
{{- $name := .Chart.Name -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "seafile.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "seafile.labels" -}}
helm.sh/chart: {{ include "seafile.chart" . }}
{{ include "seafile.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels — only these go into the selector, so the chart
version is not included here: it changes on upgrade, and the selector
is immutable.
*/}}
{{- define "seafile.selectorLabels" -}}
app.kubernetes.io/name: {{ include "seafile.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "seafile.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "seafile.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "seafile.image" -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}

{{- define "seafile.mariadb.fullname" -}}
{{- printf "%s-mariadb" (include "seafile.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "seafile.redis.fullname" -}}
{{- printf "%s-redis" (include "seafile.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Database address. An explicit host wins; otherwise the built-in
service is used. A disabled built-in database with no host is a
render-time error, not a silent deploy into the void.
*/}}
{{- define "seafile.database.host" -}}
{{- if .Values.database.host -}}
{{- .Values.database.host -}}
{{- else if .Values.database.enabled -}}
{{- printf "%s.%s.svc.%s" (include "seafile.mariadb.fullname" .) .Release.Namespace .Values.clusterDomain -}}
{{- else -}}
{{- required "database.host is required when database.enabled is false" "" -}}
{{- end -}}
{{- end -}}

{{- define "seafile.cache.host" -}}
{{- if .Values.cache.host -}}
{{- .Values.cache.host -}}
{{- else if .Values.cache.enabled -}}
{{- printf "%s.%s.svc.%s" (include "seafile.redis.fullname" .) .Release.Namespace .Values.clusterDomain -}}
{{- else -}}
{{- required "cache.host is required when cache.enabled is false" "" -}}
{{- end -}}
{{- end -}}

{{- define "seafile.secretName" -}}
{{- default (include "seafile.fullname" .) .Values.seafile.existingSecret -}}
{{- end -}}

{{- define "seafile.database.secretName" -}}
{{- default (include "seafile.mariadb.fullname" .) .Values.database.existingSecret -}}
{{- end -}}

{{- define "seafile.cache.secretName" -}}
{{- default (include "seafile.redis.fullname" .) .Values.cache.existingSecret -}}
{{- end -}}
