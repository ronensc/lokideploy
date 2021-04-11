#!/bin/bash

source ./deploy_functions.sh

collector="promtail"

show_usage() {
  echo "
usage: deploy_loki_to_openshift [options]
  options:
    -c  --collector=[enum]  Logs collector (promtail, none  default: promtail)
    -h, --help              Show usage
"
  exit 0
}

for i in "$@"
do
case $i in
    --nothing) nothing=true; shift ;;
    -c=*|--collector=*) collector="${i#*=}"; shift ;;
    -h|--help|*) show_usage ;;
esac
done

show_configuration() {

echo "
Note: get more deployment options with -h

Configuration:
-=-=-=-=-=-=-
Logs collector --> $collector

"
}

main() {
  show_configuration
  delete_loki_project_if_exists
  create_loki_project
  set_security_parameters
  enable_user_workload_monitoring
  add_helm_repository
  deploy_minio
  deploy_loki_distributed_helm_chart
  deploy_grafana_helm_chart
  case "$collector" in
    'promtail')   deploy_promtail_helm_chart;;
    'none') echo "==> Collector will not be deployed (none)";;
    *) show_usage ;;
  esac
  print_pods_status
  print_usage_instructions
}

main


