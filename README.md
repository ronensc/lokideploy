# lokideploy

## deploy
To deploy execute the following  

`./deploy_loki_to_openshift.sh`

## Details  

The deploy code is executing the following steps   

==> creating loki project
==> setting security parameters
==> enable user workload monitoring
==> deploy minio
==> deploying loki (using helm)
==> deploying grafana (using helm)
==> deploying promtail (using helm)

Exampe output of  pods and details after deployment looks like this

```
NAME                                                   READY   STATUS        RESTARTS   AGE
grafana-7886987fc7-qr5mh                               1/1     Running       0          26s
loki-loki-distributed-distributor-67b5d8d8bc-j8vgn     1/1     Running       0          60s
loki-loki-distributed-distributor-67b5d8d8bc-r52h4     1/1     Running       0          60s
loki-loki-distributed-distributor-67b5d8d8bc-svcvm     1/1     Running       0          60s
loki-loki-distributed-memcached-chunks-0               1/1     Running       0          59s
loki-loki-distributed-memcached-frontend-0             1/1     Running       0          59s
loki-loki-distributed-memcached-index-queries-0        1/1     Running       0          59s
loki-loki-distributed-memcached-index-writes-0         1/1     Running       0          59s
loki-loki-distributed-querier-0                        1/1     Running       0          59s
loki-loki-distributed-querier-1                        0/1     Running       0          18s
loki-loki-distributed-query-frontend-6575786b8-75wjv   1/1     Running       0          60s
loki-loki-distributed-query-frontend-6575786b8-r48g4   1/1     Running       0          60s
loki-loki-distributed-query-frontend-6575786b8-wjm4z   1/1     Running       0          60s
minio-5947bcbbbc-5hbm7                                 2/2     Running       0          6m24s
promtail-2zq2k                                         0/1     Terminating   0          1s
promtail-42p6j                                         0/1     Terminating   0          2s
promtail-4ksnt                                         1/1     Terminating   0          2m47s
promtail-5zkdg                                         1/1     Terminating   0          2m46s
promtail-cvqs5                                         1/1     Terminating   0          2m47s
promtail-cxfp4                                         0/1     Terminating   0          1s
promtail-f7sw8                                         0/1     Terminating   0          2s
promtail-l4s7n                                         1/1     Terminating   0          2m42s
promtail-pp2bn                                         0/1     Terminating   0          1s
promtail-qnkcm                                         0/1     Terminating   0          2s
promtail-vkgbl                                         1/1     Terminating   0          2m47s
promtail-z8q6p                                         1/1     Terminating   0          2m46s

open browser agasint http://grafana-loki.apps.eraichst-040820210903.devcluster.openshift.com

user: admin password: password



expore loki data in minio:: oc logs minio-5947bcbbbc-5hbm7 -c minio-mc


Example: under explore tab change datasource to "Loki", change time to "last 24 hours" and run query like:

 {job="openshift-dns/dns-default"}
 {app="loki-distributed"} | logfmt | entries > 1

```

