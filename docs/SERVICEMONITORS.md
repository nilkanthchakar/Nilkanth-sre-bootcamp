# ServiceMonitor / Probe Examples

This file contains example `ServiceMonitor` and `Probe` manifests you can use or customize for scraping `student-api`, Postgres exporter, and health probes via the Prometheus Operator.

Example: ServiceMonitor for `student-api` (exposes actuator/metrics)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: student-api-servicemonitor
  namespace: observability
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: student-api
  namespaceSelector:
    matchNames:
      - student-api
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 30s
      honorLabels: true
```

Example: Probe using blackbox-exporter for `/actuator/health`
```yaml
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: student-api-health-probe
  namespace: observability
spec:
  jobName: student-api-health
  module: http_2xx
  prober:
    service:
      name: blackbox-exporter
      port: http
  target:
    http:
      url: http://student-api.student-api.svc.cluster.local:8080/actuator/health
  interval: 30s
  probeTimeout: 10s
```

Applying the examples
```bash
kubectl apply -f path/to/your/ServiceMonitor.yaml -n observability
kubectl apply -f path/to/your/Probe.yaml -n observability
```

Notes
- Ensure the `ServiceMonitor`'s selector matches the labels on the target `Service` and that the `port` name matches the service port name (e.g., `http`).
- `ServiceMonitor` and `Probe` resources require the Prometheus Operator CRDs to be installed (installed by `kube-prometheus-stack`).
- If you manage resources via Argo CD, put these manifests under a folder tracked by Argo CD and create an `Application` for them.
