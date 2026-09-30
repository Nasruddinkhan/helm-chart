{{/*
Render a ConfigMap for one workload.
*/}}
{{- define "application-stack.workloadConfigMap" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- $config := default (dict) $workload.config -}}
{{- if and (ne $workload.enabled false) (eq $config.enabled true) }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}-config
  labels:
    {{- include "application-stack.workloadLabels" (list $root $key $workload) | nindent 4 }}
data:
  {{- toYaml (default (dict) $config.data) | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Render a Secret for one workload.
*/}}
{{- define "application-stack.workloadSecret" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- $secret := default (dict) $workload.secret -}}
{{- if and (ne $workload.enabled false) (eq $secret.enabled true) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}-secret
  labels:
    {{- include "application-stack.workloadLabels" (list $root $key $workload) | nindent 4 }}
type: {{ default "Opaque" $secret.type }}
{{- with $secret.data }}
data:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $secret.stringData }}
stringData:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Render a Deployment for one workload.
*/}}
{{- define "application-stack.workloadDeployment" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- if ne $workload.enabled false }}
{{- $autoscaling := default (dict) $workload.autoscaling }}
{{- $config := default (dict) $workload.config }}
{{- $secret := default (dict) $workload.secret }}
{{- $oracle := default (dict) $root.Values.oracle }}
{{- $workloadOracle := default (dict) $workload.oracle }}
{{- $probes := default (dict) $workload.probes }}
{{- $liveness := default (dict) $probes.liveness }}
{{- $readiness := default (dict) $probes.readiness }}
{{- $podAnnotations := merge (dict) (default (dict) $root.Values.global.podAnnotations) (default (dict) $workload.podAnnotations) }}
{{- $podLabels := merge (dict) (default (dict) $root.Values.global.podLabels) (default (dict) $workload.podLabels) }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}
  labels:
    {{- include "application-stack.workloadLabels" (list $root $key $workload) | nindent 4 }}
spec:
  {{- if not (eq $autoscaling.enabled true) }}
  replicas: {{ default 1 $workload.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "application-stack.selectorLabels" (list $root $key $workload) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "application-stack.selectorLabels" (list $root $key $workload) | nindent 8 }}
        {{- with $podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      serviceAccountName: {{ include "application-stack.serviceAccountName" $root }}
      {{- with $root.Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $workload.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $workload.initContainers }}
      initContainers:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ include "application-stack.workloadName" (list $root $key $workload) }}
          image: "{{ required (printf "workloads.%s.image.repository is required" $key) $workload.image.repository }}:{{ default $root.Chart.AppVersion $workload.image.tag }}"
          imagePullPolicy: {{ default "IfNotPresent" $workload.image.pullPolicy }}
          {{- with $workload.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $workload.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ default 8080 $workload.containerPort }}
              protocol: TCP
          {{- with $workload.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if or $workload.envFrom (and (eq $config.enabled true) (ne $config.mountAsEnv false)) (eq $secret.enabled true) (and (eq $oracle.enabled true) (eq $workloadOracle.enabled true)) }}
          envFrom:
            {{- if and (eq $config.enabled true) (ne $config.mountAsEnv false) }}
            - configMapRef:
                name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}-config
            {{- end }}
            {{- if and (eq $oracle.enabled true) (eq $workloadOracle.enabled true) }}
            - configMapRef:
                name: {{ include "application-stack.oracleConfigMapName" $root }}
            - secretRef:
                name: {{ include "application-stack.oracleSecretName" $root }}
            {{- end }}
            {{- if eq $secret.enabled true }}
            - secretRef:
                name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}-secret
            {{- end }}
            {{- with $workload.envFrom }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- if eq $liveness.enabled true }}
          livenessProbe:
            httpGet:
              path: {{ default "/" $liveness.path }}
              port: http
            initialDelaySeconds: {{ default 30 $liveness.initialDelaySeconds }}
            periodSeconds: {{ default 10 $liveness.periodSeconds }}
            timeoutSeconds: {{ default 5 $liveness.timeoutSeconds }}
            failureThreshold: {{ default 3 $liveness.failureThreshold }}
          {{- end }}
          {{- if eq $readiness.enabled true }}
          readinessProbe:
            httpGet:
              path: {{ default "/" $readiness.path }}
              port: http
            initialDelaySeconds: {{ default 15 $readiness.initialDelaySeconds }}
            periodSeconds: {{ default 10 $readiness.periodSeconds }}
            timeoutSeconds: {{ default 5 $readiness.timeoutSeconds }}
            failureThreshold: {{ default 3 $readiness.failureThreshold }}
          {{- end }}
          {{- with $workload.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $workload.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $workload.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
        {{- with $workload.sidecars }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $workload.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $workload.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $workload.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $workload.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
{{- end -}}

{{/*
Render a Service for one workload.
*/}}
{{- define "application-stack.workloadService" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- $service := default (dict) $workload.service -}}
{{- if and (ne $workload.enabled false) (ne $service.enabled false) }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}
  labels:
    {{- include "application-stack.workloadLabels" (list $root $key $workload) | nindent 4 }}
  {{- with $service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ default "ClusterIP" $service.type }}
  ports:
    - port: {{ default 80 $service.port }}
      targetPort: {{ default "http" $service.targetPort }}
      protocol: TCP
      name: http
      {{- with $service.nodePort }}
      nodePort: {{ . }}
      {{- end }}
  selector:
    {{- include "application-stack.selectorLabels" (list $root $key $workload) | nindent 4 }}
{{- end }}
{{- end -}}

{{/*
Render an Ingress for one workload.
*/}}
{{- define "application-stack.workloadIngress" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- $ingress := default (dict) $workload.ingress -}}
{{- $service := default (dict) $workload.service -}}
{{- if and (ne $workload.enabled false) (eq $ingress.enabled true) (ne $service.enabled false) }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}
  labels:
    {{- include "application-stack.workloadLabels" (list $root $key $workload) | nindent 4 }}
  {{- with $ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with $ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range $ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ default "Prefix" .pathType }}
            backend:
              service:
                name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}
                port:
                  number: {{ default 80 $service.port }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end -}}

{{/*
Render an HPA for one workload.
*/}}
{{- define "application-stack.workloadHpa" -}}
{{- $root := index . 0 -}}
{{- $key := index . 1 -}}
{{- $workload := index . 2 -}}
{{- $autoscaling := default (dict) $workload.autoscaling -}}
{{- if and (ne $workload.enabled false) (eq $autoscaling.enabled true) }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}
  labels:
    {{- include "application-stack.workloadLabels" (list $root $key $workload) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "application-stack.workloadFullname" (list $root $key $workload) }}
  minReplicas: {{ default 1 $autoscaling.minReplicas }}
  maxReplicas: {{ default 3 $autoscaling.maxReplicas }}
  metrics:
    {{- if $autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end -}}
