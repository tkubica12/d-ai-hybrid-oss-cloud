{{/*
Generate the full name for resources
*/}}
{{- define "kaito-models.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kaito-models.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- range $key, $value := .Values.commonLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels for a specific model
*/}}
{{- define "kaito-models.selectorLabels" -}}
kaito.sh/workspace: workspace-{{ . }}
{{- end }}
