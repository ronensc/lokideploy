#!/bin/bash

show_usage() {
  #TODO: UPDATE
  echo "
usage: deploy_loki_to_openshift [options]
  options:
    -c    --collector=[enum]                Logs collector   (promtail, none  default: none)
    -dm   --deploy_minio=[bool]             deploy_minio ( default: false)
    -r    --replicas=[num]                  Loki microservices replicas ( default: 2)
    -ir   --ingester_replicas=[num]         Loki ingester replicas ( default: \$replicas)
    -dr   --distributor_replicas=[num]      Loki distributor replicas ( default: \$replicas)
    -qr   --querier_replicas=[num]          Loki querier replicas ( default: \$replicas)
    -qr   --query_frontend_replicas=[num]   Loki query frontend replicas ( default: \$replicas)
    -sp   --stress_profile=[enum]           Stress profile against loki ( none,light,medium,heavy default: none)
    -s3ep --s3_endpoint=[string]            S3 end-point ( default: s3://user:password@minio.loki.svc.cluster.local:9000/bucket)
    -h,   --help                            Show usage
"
  exit 0
}

show_configuration() {

echo "
Note: get more deployment options with -h

Configuration:
-=-=-=-=-=-=-
Logs collector --> $collector
Loki ingester replicas --> $ingester_replicas
Loki distributor replicas --> $distributor_replicas
Loki querier replicas --> $querier_replicas
Loki query frontend replicas --> $query_frontend_replicas
Stress profile --> $stress_profile
Deploy minio --> $deploy_minio
S3 End Point  --> $s3_endpoint
"
}

deploy() {
  show_configuration
  delete_loki_project_if_exists
  create_loki_project
  enable_user_workload_monitoring
  add_helm_repository
  if [ "$deploy_minio" = "true" ]; then
    deploy_minio;
  fi
  deploy_loki_distributed_helm_chart \
    "$ingester_replicas" \
    "$distributor_replicas" \
    "$querier_replicas" \
    "$query_frontend_replicas" \
    "$s3_endpoint"
  deploy_grafana_helm_chart
  case "$collector" in
    'promtail')   deploy_promtail_helm_chart;;
    'none') echo "==> Collector will not be deployed (none)";;
    *) show_usage ;;
  esac
  case "$stress_profile" in
    'none') echo "";;
    'light') deploy_stress 1 1 1  1 1;;
    'medium') deploy_stress 2 1000 100  1 1;;
    'heavy') deploy_stress 5 10000 1000 1 1;;
    *) show_usage ;;
  esac
}

RUNNING="$(basename $(echo "$0" | sed 's/-//g'))"
if [[ "$RUNNING" == "deploy_loki_to_openshift.sh" ]]
then

  source ./contrib/deploy_functions.sh

  #default parameters
  collector="none"
  replicas=2
  stress_profile="none"
  deploy_minio=false
  s3_endpoint="s3://user:password@minio.loki.svc.cluster.local:9000/bucket"

  for i in "$@"
  do
  case $i in
      -c=*|--collector=*) collector="${i#*=}"; shift ;;
      -dm=*|--deploy_minio=*) deploy_minio="${i#*=}"; shift ;;
      -r=*|--replicas=*) replicas="${i#*=}"; shift ;;
      -ir=*|--ingester_replicas=*) ingester_replicas="${i#*=}"; shift ;;
      -dr=*|--distributor_replicas=*) distributor_replicas="${i#*=}"; shift ;;
      -qr=*|--querier_replicas=*) querier_replicas="${i#*=}"; shift ;;
      -qfr=*|--query_frontend_replicas=*) query_frontend_replicas="${i#*=}"; shift ;;
      -sp=*|--stress_profile=*) stress_profile="${i#*=}"; shift ;;
      -s3ep=*|--s3_endpoint=*) s3_endpoint="${i#*=}"; shift ;;
      -h|--help|*) show_usage ;;
  esac
  done

  # Assign $replicas as default value if specific component replica isn't set in the command line args
  # https://stackoverflow.com/a/28085062/2749989
  : "${ingester_replicas:=$replicas}"
  : "${distributor_replicas:=$replicas}"
  : "${querier_replicas:=$replicas}"
  : "${query_frontend_replicas:=$replicas}"

  deploy "$@"
  print_pods_status
  print_usage_instructions
fi


