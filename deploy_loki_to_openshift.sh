#!/bin/bash

source ./deploy_functions.sh


show_usage() {
  echo "
usage: deploy_loki_to_openshift [options]
  options:
    -h, --help              Show usage
"
  exit 0
}

for i in "$@"
do
case $i in
    --nothing) nothing=true; shift ;;
    -h|--help|*) show_usage ;;
esac
done

main() {
  create_loki_project
  set_security_parameters
  enable_user_workload_monitoring
  add_helm_repository
  deploy_minio
  deploy_loki_distributed_helm_chart
  deploy_grafana_helm_chart
  deploy_promtail_helm_chart
  print_pods_status
  print_usage_instructions
}

main


