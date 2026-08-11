#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "tmpdir"
require "yaml"

CHART = File.expand_path("..", __dir__)
VALUES = File.join(__dir__, "values.yaml")
KUBERNETES_VERSION = "1.36.2"
IMAGE = "ghcr.io/geodesa-ai/console-bff:0.1.0@sha256:#{"a" * 64}"

def run!(*command)
  stdout, stderr, status = Open3.capture3(*command)
  return stdout if status.success?

  warn stdout unless stdout.empty?
  warn stderr unless stderr.empty?
  abort "#{command.join(" ")} failed with status #{status.exitstatus}"
end

def resources_of_kind(resources, kind)
  resources.select { |resource| resource.fetch("kind", nil) == kind }
end

def one_resource(resources, kind)
  matches = resources_of_kind(resources, kind)
  raise "expected one #{kind}, rendered #{matches.length}" unless matches.length == 1

  matches.first
end

Dir.mktmpdir("geodesa-app-helm-") do |directory|
  repository_config = File.join(directory, "repositories.yaml")
  repository_cache = File.join(directory, "repository")
  run!(
    "helm", "repo", "add", "bjw-s", "https://bjw-s-labs.github.io/helm-charts",
    "--repository-config", repository_config,
    "--repository-cache", repository_cache
  )
  run!(
    "helm", "dependency", "build", CHART,
    "--repository-config", repository_config,
    "--repository-cache", repository_cache
  )
end
run!(
  "helm", "lint", CHART, "--strict", "--values", VALUES,
  "--kube-version", KUBERNETES_VERSION
)
rendered = run!(
  "helm", "template", "geodesa-api", CHART,
  "--namespace", "apps",
  "--values", VALUES,
  "--kube-version", KUBERNETES_VERSION,
  "--api-versions", "gateway.networking.k8s.io/v1/HTTPRoute",
  "--api-versions", "gateway.networking.k8s.io/v1beta1/ReferenceGrant"
)
resources = YAML.load_stream(rendered).compact

%w[Ingress Secret ServiceAccount].each do |kind|
  raise "chart rendered forbidden #{kind}" unless resources_of_kind(resources, kind).empty?
end

deployment = one_resource(resources, "Deployment")
service = one_resource(resources, "Service")
pdb = one_resource(resources, "PodDisruptionBudget")
migration = one_resource(resources, "Job")
route = one_resource(resources, "HTTPRoute")
grant = one_resource(resources, "ReferenceGrant")

pod = deployment.fetch("spec").fetch("template").fetch("spec")
container = pod.fetch("containers").fetch(0)
raise "zero-downtime rollout policy missing" unless deployment.dig("spec", "strategy") == {
  "type" => "RollingUpdate",
  "rollingUpdate" => { "maxSurge" => 1, "maxUnavailable" => 0 }
}
raise "deployment image is not immutable" unless container.fetch("image") == IMAGE
raise "wrong existing ServiceAccount" unless pod.fetch("serviceAccountName") == "geodesa-api"
raise "service account token was mounted" unless pod.fetch("automountServiceAccountToken") == false
raise "termination grace missing" unless pod.fetch("terminationGracePeriodSeconds") == 45
raise "restricted pod context missing" unless pod.dig("securityContext", "runAsNonRoot") == true
raise "RuntimeDefault missing" unless pod.dig("securityContext", "seccompProfile", "type") == "RuntimeDefault"
raise "privilege escalation enabled" unless container.dig("securityContext", "allowPrivilegeEscalation") == false
raise "root filesystem is writable" unless container.dig("securityContext", "readOnlyRootFilesystem") == true
raise "capabilities not dropped" unless container.dig("securityContext", "capabilities", "drop") == ["ALL"]
raise "resource contract missing" unless container.fetch("resources") == {
  "limits" => { "cpu" => "1", "memory" => "512Mi" },
  "requests" => { "cpu" => "100m", "memory" => "128Mi" }
}
raise "HTTP port missing" unless container.fetch("ports").any? { |port| port == { "containerPort" => 8080, "name" => "http", "protocol" => "TCP" } }
raise "readiness probe missing" unless container.dig("readinessProbe", "httpGet", "path") == "/health/ready"
raise "liveness probe missing" unless container.dig("livenessProbe", "httpGet", "path") == "/health/live"
raise "startup probe missing" unless container.dig("startupProbe", "failureThreshold") == 30
raise "env valueFrom missing" unless container.fetch("env").any? { |env| env.fetch("name") == "DATABASE_URL" && env.dig("valueFrom", "secretKeyRef", "name") == "geodesa-api-database" }
raise "OTLP env missing" unless container.fetch("env").any? { |env| env == { "name" => "OTEL_EXPORTER_OTLP_ENDPOINT", "value" => "http://otel-collector.observability-system.svc:4318" } }
raise "envFrom references missing" unless container.fetch("envFrom") == [
  { "configMapRef" => { "name" => "geodesa-api-config" } },
  { "secretRef" => { "name" => "geodesa-api-runtime" } }
]
raise "anti-affinity missing" unless pod.dig("affinity", "podAntiAffinity")
raise "topology spread missing" unless pod.fetch("topologySpreadConstraints").length == 1

volumes = pod.fetch("volumes")
raise "Secret volume missing" unless volumes.any? { |volume| volume.dig("secret", "secretName") == "geodesa-api-database-certificate" }
raise "projected volume missing" unless volumes.any? { |volume| volume.key?("projected") }
raise "CSI volume missing" unless volumes.any? { |volume| volume.dig("csi", "driver") == "secrets-store.csi.k8s.io" }

raise "service is not ClusterIP" unless service.dig("spec", "type") == "ClusterIP"
raise "service port contract missing" unless service.dig("spec", "ports") == [
  { "name" => "http", "port" => 80, "protocol" => "TCP", "targetPort" => 8080 }
]
raise "PDB contract missing" unless pdb.dig("spec", "maxUnavailable") == 1

migration_spec = migration.fetch("spec")
migration_pod = migration_spec.fetch("template").fetch("spec")
migration_container = migration_pod.fetch("containers").fetch(0)
raise "migration hook missing" unless migration.dig("metadata", "annotations", "helm.sh/hook") == "pre-install,pre-upgrade"
raise "migration hook delete policy missing" unless migration.dig("metadata", "annotations", "helm.sh/hook-delete-policy") == "before-hook-creation,hook-succeeded"
raise "migration image differs" unless migration_container.fetch("image") == IMAGE
raise "migration retries are not finite" unless migration_spec.fetch("backoffLimit") == 2
raise "migration deadline missing" unless migration_spec.fetch("activeDeadlineSeconds") == 600
raise "migration restart policy wrong" unless migration_pod.fetch("restartPolicy") == "Never"
raise "migration command missing" unless migration_container.fetch("command") == ["/app/console-bff"]
raise "migration args missing" unless migration_container.fetch("args") == ["migrate"]

raise "HTTPRoute did not attach to the private Gateway" unless route.dig("spec", "parentRefs", 0) == {
  "group" => "gateway.networking.k8s.io",
  "kind" => "Gateway",
  "name" => "platform-internal",
  "namespace" => "gateway-system",
  "sectionName" => "websecure"
}
raise "HTTPRoute backend missing" unless route.dig("spec", "rules", 0, "backendRefs", 0, "name") == "geodesa-api"
raise "ReferenceGrant source wrong" unless grant.dig("spec", "from", 0, "namespace") == "gateway-system"
raise "ReferenceGrant target wrong" unless grant.dig("spec", "to", 0) == {
  "group" => "",
  "kind" => "Service",
  "name" => "geodesa-api"
}

puts "geodesa-app rendered contract verified on Kubernetes #{KUBERNETES_VERSION}"
