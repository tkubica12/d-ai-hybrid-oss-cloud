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
/subscriptions/{{ required "apim.subscriptionId is required" .Values.apim.subscriptionId }}/resourceGroups/{{ required "apim.resourceGroup is required" .Values.apim.resourceGroup }}/providers/Microsoft.ApiManagement/service/{{ required "apim.name is required" .Values.apim.name }}
{{- end }}

{{/* Foundry Resource ARM ID */}}
{{- define "developer-access.foundryArmId" -}}
/subscriptions/{{ required "apim.subscriptionId is required" .Values.apim.subscriptionId }}/resourceGroups/{{ required "foundry.resourceGroup is required" .Values.foundry.resourceGroup }}/providers/Microsoft.CognitiveServices/accounts/{{ required "foundry.resourceName is required" .Values.foundry.resourceName }}
{{- end }}

{{/* Product name */}}
{{- define "developer-access.productName" -}}
product-{{ include "developer-access.teamName" . }}
{{- end }}

{{/* Subscription name */}}
{{- define "developer-access.subscriptionName" -}}
subscription-{{ include "developer-access.teamName" . }}
{{- end }}
