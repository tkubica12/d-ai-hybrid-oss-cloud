{{/* Common labels */}}
{{- define "ai-gateway.labels" -}}
app.kubernetes.io/name: ai-gateway
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Resource Group name */}}
{{- define "ai-gateway.resourceGroupName" -}}
{{ .Values.resourceGroup.name }}
{{- end }}

{{/* Resource Group ARM ID - used for owner references to existing resource groups */}}
{{- define "ai-gateway.resourceGroupArmId" -}}
/subscriptions/{{ .Values.subscriptionId }}/resourceGroups/{{ .Values.resourceGroup.name }}
{{- end }}
