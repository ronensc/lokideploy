#!/bin/bash

source ./deploy_functions.sh

collector="none"
replicas=3
stress_profile="none"

show_usage() {
  echo "
usage: deploy_loki_to_openshift [options]
  options:
    -c   --collector=[enum]       Logs collector (promtail, none  default: none)
    -r   --replicas=[num]         Loki microservices replicas ( default: 2)
    -sp  --stress_profile=[enum]  Stress profile against loki ( none,light,medium,heavy default: none)
    -h,  --help                   Show usage
"
  exit 0
}

for i in "$@"
do
case $i in
    -c=*|--collector=*) collector="${i#*=}"; shift ;;
    -r=*|--replicas=*) replicas="${i#*=}"; shift ;;
    -sp=*|--stress_profile=*) stress_profile="${i#*=}"; shift ;;
    -h|--help|*) show_usage ;;
esac
done

show_configuration() {

echo "
Note: get more deployment options with -h

Configuration:
-=-=-=-=-=-=-
Logs collector --> $collector
Loki microservices replicas --> $replicas
Stress profile --> $stress_profile

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
  deploy_loki_distributed_helm_chart "$replicas"
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

  print_pods_status
  print_usage_instructions
}

main


