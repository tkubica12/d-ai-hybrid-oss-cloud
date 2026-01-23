{{/* Common labels */}}
{{- define "developer-access.labels" -}}
app.kubernetes.io/name: developer-access
app.kubernetes.io/instance: {{ .Values.team.name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
ai.contoso.com/team: {{ .Values.team.name }}
{{- if .Values.team.costCenter }}
ai.contoso.com/cost-center: {{ .Values.team.costCenter | quote }}
{{- end }}
{{- end }}

{{/* Team name with validation */}}
{{- define "developer-access.teamName" -}}
{{- required "team.name is required" .Values.team.name -}}
{{- end }}

{{/* APIM Service ARM ID */}}
{{- define "developer-access.apimArmId" -}}
/subscriptions/{{ required "apim.subscriptionId is required" .Values.apim.subscriptionId }}/resourceGroups/{{ .Values.apim.resourceGroup }}/providers/Microsoft.ApiManagement/service/{{ .Values.apim.name }}
{{- end }}

{{/* Product name */}}
{{- define "developer-access.productName" -}}
product-{{ include "developer-access.teamName" . }}
{{- end }}

{{/* Subscription name */}}
{{- define "developer-access.subscriptionName" -}}
subscription-{{ include "developer-access.teamName" . }}
{{- end }}
