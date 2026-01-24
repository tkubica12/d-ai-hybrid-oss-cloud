{{/* Common labels */}}
{{- define "developer-access.labels" -}}
app.kubernetes.io/name: developer-access
app.kubernetes.io/instance: {{ .Values.team.name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
ai.contoso.com/team: {{ .Values.team.name }}
{{- end }}

{{/* Team name with validation */}}
{{- define "developer-access.teamName" -}}
{{- required "team.name is required" .Values.team.name -}}
{{- end }}
