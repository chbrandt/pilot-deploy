{{/* _helpers.tpl — Named templates for the HPC Pilot chart. */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "manager.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Full name: release-chart (truncated to 63 chars).
When the release name already contains the chart name the chart suffix is
dropped to avoid redundant names like "manager-manager".
*/}}
{{- define "manager.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "manager.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Resource names for the two services (suffixes -api / -app).
*/}}
{{- define "manager.apiName" -}}
{{- printf "%s-api" (include "manager.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "manager.appName" -}}
{{- printf "%s-app" (include "manager.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/* Common labels applied to every resource. */}}
{{- define "manager.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels (stable subset) per component — Deployment/Service pairs.
*/}}
{{- define "manager.apiSelectorLabels" -}}
app.kubernetes.io/name: {{ include "manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: api
{{- end -}}

{{- define "manager.appSelectorLabels" -}}
app.kubernetes.io/name: {{ include "manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: app
{{- end -}}

{{/* Name of the ServiceAccount to use (needed by the API service). */}}
{{- define "manager.serviceAccountName" -}}
{{- .Values.namespace -}}-sa
{{- end -}}

{{/*
Secret carrying the FLASK_SECRET_KEYs (and the optional OIDC client secret).
When existingSecret values are set, those Secrets are used; otherwise the
chart creates its own Secret named after the release.
*/}}
{{- define "manager.apiSecretName" -}}
{{- if .Values.api.flask.existingSecret -}}
{{- .Values.api.flask.existingSecret -}}
{{- else -}}
{{- include "manager.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "manager.appSecretName" -}}
{{- if .Values.app.flask.existingSecret -}}
{{- .Values.app.flask.existingSecret -}}
{{- else -}}
{{- include "manager.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "manager.oidcSecretName" -}}
{{- if .Values.api.existingOidcSecret -}}
{{- .Values.api.existingOidcSecret -}}
{{- else -}}
{{- include "manager.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Name of the PVC for saved-deployment data (API-owned). */}}
{{- define "manager.pvcName" -}}
{{- if and .Values.api.persistence.enabled .Values.api.persistence.existingClaim }}
{{- .Values.api.persistence.existingClaim -}}
{{- else }}
{{- printf "%s-data" (include "manager.fullname" .) }}
{{- end }}
{{- end -}}
