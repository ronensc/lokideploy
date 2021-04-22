#!/bin/bash

# create loki project
create_loki_project() {
  echo "==> creating loki project"
  oc adm new-project loki
  oc project loki
}

# delete loki project if it exists (to get new fresh deployment)
delete_loki_project_if_exists() {
PROJECT_LOKI=$(oc get project | grep loki)
if [ -n "$PROJECT_LOKI" ]; then
  echo "--> Deleting loki namespace"
  oc delete project loki
  while : ; do
    PROJECT_LOKI=$(oc get project | grep loki)
    if [ -z "$PROJECT_LOKI" ]; then break; fi
    sleep 1
  done
fi
}


# set  security
set_security_parameters() {
  echo "==> setting security parameters"
  oc adm policy add-scc-to-group anyuid system:authenticated
  oc patch scc restricted --type=json -p '[{"op": "replace", "path": "/allowHostDirVolumePlugin", "value":true}]'
  oc patch scc restricted --type=json -p '[{"op": "replace", "path": "/allowPrivilegedContainer", "value":true}]'
}

# add helm to repository
add_helm_repository() {
  echo "adding helm repository"
  helm repo add grafana https://grafana.github.io/helm-charts
}

# deploy loki (distributed)
deploy_loki_distributed_helm_chart() {
  replicats=$1
  echo "==> deploying loki (using helm) - with $replicats replicas"
  helm delete loki -n loki
  cat > tmp/loki-values.yaml <<- EOF
loki:
  config: |
    auth_enabled: false

    server:
      log_level: info
      # Must be set to 3100
      http_listen_port: 3100
      grpc_server_max_recv_msg_size: 16000000
      grpc_server_max_send_msg_size: 16000000

    distributor:
      ring:
        kvstore:
          store: memberlist

    ingester:
      lifecycler:
        ring:
          kvstore:
            store: memberlist

    memberlist:
      join_members:
        - {{ include "loki.fullname" . }}-memberlist

    limits_config:
      ingestion_rate_mb: 1000
      ingestion_burst_size_mb: 1000
      max_concurrent_tail_requests: 1000
      max_cache_freshness_per_query: 1m

    schema_config:
      configs:
        - from: 2020-09-07
          store: boltdb-shipper
          object_store: aws
          schema: v11
          index:
            prefix: loki_index_
            period: 24h

    storage_config:
      aws:
        s3: s3://user:password@minio.loki.svc.cluster.local:9000
        bucketnames: bucket
        s3forcepathstyle: true
      boltdb_shipper:
        shared_store: s3
        active_index_directory: /var/loki/index
        cache_location: /var/loki/cache  

    frontend_worker:
      frontend_address: {{ include "loki.queryFrontendFullname" . }}:9095

    frontend:
      log_queries_longer_than: 5s
      compress_responses: true
gateway:
  enabled: false
distributor:
  replicas: ${replicats}
querier:
  replicas: ${replicats}
queryFrontend:
  replicas: ${replicats}
ingester:
  replicas: ${replicats}
  persistence: 
    enabled: true
memcachedChunks:
  enabled: true
memcachedFrontend:
  enabled: true
memcachedIndexQueries: 
  enabled: true
memcachedIndexWrites:
  enabled: true
serviceMonitor:
  enabled: true
EOF
  helm upgrade --install loki grafana/loki-distributed --namespace=loki -f tmp/loki-values.yaml
  oc delete -n loki route loki-loki-distributed-query-frontend
  oc expose -n loki service loki-loki-distributed-query-frontend
  oc delete -n loki route loki-loki-distributed-distributor
  oc expose -n loki service loki-loki-distributed-distributor
  oc get route -n loki
}

# deploy grafana
deploy_grafana_helm_chart() {
  echo "==> deploying grafana (using helm)"
  helm delete grafana -n loki
  cat > tmp/grafana-values.yaml <<- EOF
adminUser: admin
adminPassword: password
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: loki
      type: loki
      access: proxy
      url: http://loki-loki-distributed-query-frontend.loki.svc.cluster.local:3100
EOF
  helm upgrade --install grafana grafana/grafana --namespace=loki -f tmp/grafana-values.yaml
  oc delete -n loki route grafana
  oc expose -n loki service grafana
  oc get route -n loki
}

# deploy promtail
deploy_promtail_helm_chart() {
  echo "==> deploying promtail (using helm)"
  helm delete promtail -n loki
  cat > tmp/promtail-values.yaml <<- EOF
config:
  logLevel: "info"
  lokiAddress: "http://loki-loki-distributed-distributor.loki.svc.cluster.local:3100/loki/api/v1/push"
containerSecurityContext:
  allowPrivilegeEscalation: true
podSecurityContext:
  runAsUser: 100
  runAsGroup: 100
EOF
  helm upgrade --install promtail grafana/promtail --namespace=loki -f tmp/promtail-values.yaml
  oc patch ds promtail --type=json -p '[{"op": "remove", "path": "/spec/template/spec/securityContext"}]'
  oc patch ds promtail --type=json -p '[{"op": "add", "path": "/spec/template/spec/containers/0/securityContext/privileged", "value":true}]'
}

# enable user workload monitoring 
enable_user_workload_monitoring() {
  echo "==> enable user workload monitoring"
  oc apply -f cluster-monitoring-config.yaml
}

# enable user workload monitoring 
deploy_minio() {
  echo "==> deploy minio"
  oc process -f minio_template.yaml | oc apply -f -
  oc expose -n loki service minio
}

deploy_stress() {
  echo "==> deploy stress"
  oc process -f stress_template.yaml \
    -p write_replicas="$1" \
    -p write_delay="$2" \
    -p query_replicas="$3" \
    -p query_delay="$4" \
    | oc apply -f -
}

# print pod status
print_pods_status() {
  echo -e "\n"
  oc get pods
}

# print usage instructions
print_usage_instructions() {
  GRAFANA_POD=$(oc get pod -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}")
  MINIO_POD=$(oc get pod -l app=minio -o jsonpath="{.items[0].metadata.name}")

  echo -e "Waiting for $GRAFANA_POD to become ready"
  while : ; do
    POD_READY=$(oc get pod "$GRAFANA_POD" | grep Running)
    if [ -n "$POD_READY" ]; then break; fi
    sleep 1
  done
  
  GRAFANA_ROUTE_URL=$(oc get route grafana -o jsonpath="{.spec.host}")
  echo -e "\nopen browser agasint http://$GRAFANA_ROUTE_URL\n"
  echo -e "user: admin password: password\n"
  echo -e "\n\nexpore loki data in minio:: oc logs -n loki -f $MINIO_POD -c minio-mc"
  echo -e "\n\nExample: under explore tab change datasource to \"Loki\", change time to \"last 24 hours\" and run query like:\n"
  echo -e " {job=\"openshift-dns/dns-default\"}"
  echo -e " {app=\"loki-distributed\"} | logfmt | entries > 1"
  echo -e "\n\n to see resource utilization use: kubectl top pod --namespace=loki --sort-by=cpu | head -n 20;"
  
}


