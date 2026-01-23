{{/* Common labels */}}
{{- define "ai-gateway.labels" -}}
app.kubernetes.io/name: ai-gateway
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Resource Group name */}}
{{- define "ai-gateway.resourceGroupName" -}}
{{ .Values.resourceGroup.name }}
{{- end }}
