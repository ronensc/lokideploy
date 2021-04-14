# lokideploy

## Deploy
To deploy execute the following  

`./deploy_loki_to_openshift.sh`

## Usage

```bash
$ ./deploy_loki_to_openshift.sh -?

usage: deploy_loki_to_openshift [options]
  options:
    -c  --collector=[enum] Logs collector (promtail, none  default: none)
    -r  --replicas=[num]   Loki microservices replicaes ( default: 2)
    -h, --help             Show usage
```

## Details  

The deploy code is executing the following steps   

==> deleting old loki project (if exists)
==> creating loki project  
==> setting security parameters  
==> enable user workload monitoring  
==> deploy minio  
==> deploying loki (using helm)  
==> deploying grafana (using helm)  
==> deploying promtail (using helm)  

Example output of  pods and details after deployment looks like this

```
NAME                                                   READY   STATUS        RESTARTS   AGE
grafana-7886987fc7-qr5mh                               1/1     Running       0          5m35s
loki-loki-distributed-distributor-67b5d8d8bc-j8vgn     1/1     Running       0          6m9s
loki-loki-distributed-distributor-67b5d8d8bc-r52h4     1/1     Running       0          6m9s
loki-loki-distributed-distributor-67b5d8d8bc-svcvm     1/1     Running       0          6m9s
loki-loki-distributed-ingester-0                       1/1     Running       0          5m6s
loki-loki-distributed-ingester-1                       1/1     Running       0          3m51s
loki-loki-distributed-ingester-2                       1/1     Running       0          2m43s
loki-loki-distributed-memcached-chunks-0               1/1     Running       0          6m8s
loki-loki-distributed-memcached-frontend-0             1/1     Running       0          6m8s
loki-loki-distributed-memcached-index-queries-0        1/1     Running       0          6m8s
loki-loki-distributed-memcached-index-writes-0         1/1     Running       0          6m8s
loki-loki-distributed-querier-0                        1/1     Running       0          6m8s
loki-loki-distributed-querier-1                        1/1     Running       0          5m27s
loki-loki-distributed-querier-2                        1/1     Running       0          4m46s
loki-loki-distributed-query-frontend-6575786b8-75wjv   1/1     Running       0          6m9s
loki-loki-distributed-query-frontend-6575786b8-r48g4   1/1     Running       0          6m9s
loki-loki-distributed-query-frontend-6575786b8-wjm4z   1/1     Running       0          6m9s
minio-5947bcbbbc-5hbm7                                 2/2     Running       0          11m
promtail-224wc                                         1/1     Running       0          5m7s
promtail-df6q5                                         1/1     Running       0          4m56s
promtail-f7sw8                                         1/1     Running       0          5m11s
promtail-frg2h                                         1/1     Running       0          5m8s
promtail-gps66                                         1/1     Running       0          5m8s
promtail-h8gk7                                         1/1     Running       0          5m4s

open browser agasint http://grafana-loki.apps.eraichst-040820210903.devcluster.openshift.com

user: admin password: password



expore loki data in minio:: oc logs -f minio-5947bcbbbc-5hbm7 -c minio-mc


Example: under explore tab change datasource to "Loki", change time to "last 24 hours" and run query like:

 {job="openshift-dns/dns-default"}
 {app="loki-distributed"} | logfmt | entries > 1

```

