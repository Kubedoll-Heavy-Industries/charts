{{/*
Generic deployment template for Huly services.
Usage: {{ include "huly.deployment" (dict "root" . "name" "front" "config" .Values.front "port" 8087) }}
*/}}
{{- define "huly.deployment" -}}
{{- $fullname := include "huly.fullname" .root -}}
{{- $tag := .config.image.tag | default .root.Values.global.imageTag -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $fullname }}-{{ .name }}
  labels:
    {{- include "huly.labels" .root | nindent 4 }}
    app.kubernetes.io/component: {{ .name }}
spec:
  replicas: {{ .config.replicas }}
  selector:
    matchLabels:
      {{- include "huly.selectorLabels" .root | nindent 6 }}
      app.kubernetes.io/component: {{ .name }}
  template:
    metadata:
      labels:
        {{- include "huly.selectorLabels" .root | nindent 8 }}
        app.kubernetes.io/component: {{ .name }}
    spec:
      {{- with .root.Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- include "huly.podSecurityContext" .root | nindent 8 }}
      containers:
        - name: {{ .name }}
          image: "{{ .config.image.repository }}:{{ $tag }}"
          imagePullPolicy: {{ .root.Values.global.imagePullPolicy }}
          securityContext:
            {{- include "huly.containerSecurityContext" .root | nindent 12 }}
          {{- if .port }}
          ports:
            - name: http
              containerPort: {{ .port }}
              protocol: TCP
          {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "huly.configMapName" .root }}
            - secretRef:
                name: {{ include "huly.secretName" .root }}
          {{- with .extraEnv }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .config.resources | nindent 12 }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
{{- end }}
