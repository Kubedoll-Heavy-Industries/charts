{{/*
Generic service template for Huly services.
Usage: {{ include "huly.service" (dict "root" . "name" "front" "port" 8087) }}
*/}}
{{- define "huly.service" -}}
{{- $fullname := include "huly.fullname" .root -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ $fullname }}-{{ .name }}
  labels:
    {{- include "huly.labels" .root | nindent 4 }}
    app.kubernetes.io/component: {{ .name }}
spec:
  type: ClusterIP
  ports:
    - port: {{ .port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "huly.selectorLabels" .root | nindent 4 }}
    app.kubernetes.io/component: {{ .name }}
{{- end }}
