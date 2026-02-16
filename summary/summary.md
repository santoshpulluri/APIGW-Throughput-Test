```bash
curl http://34.207.111.178:8443/hello
```

Loadbalanced response with one set of instances
```json
{
  "name": "Service",
  "uri": "/hello",
  "type": "HTTP",
  "ip_addresses": [
    "172.31.28.51"
  ],
  "start_time": "2025-04-15T10:28:41.332680",
  "end_time": "2025-04-15T10:28:41.353356",
  "duration": "20.675128ms",
  "body": "Hello World",
  "upstream_calls": {
    "http://localhost:9090/response": {
      "name": "Service",
      "uri": "http://localhost:9090/response",
      "type": "HTTP",
      "ip_addresses": [
        "172.31.26.189"
      ],
      "start_time": "2025-04-15T10:28:41.346934",
      "end_time": "2025-04-15T10:28:41.347021",
      "duration": "86.645µs",
      "headers": {
        "Content-Length": "272",
        "Content-Type": "text/plain; charset=utf-8",
        "Date": "Tue, 15 Apr 2025 10:28:41 GMT",
        "Server": "envoy",
        "X-Envoy-Upstream-Service-Time": "10"
      },
      "body": "Hello World",
      "code": 200
    }
  },
  "code": 200
}
```

Loadbalanced response with other set of instances
```bash
```json
{
  "name": "Service",
  "uri": "/hello",
  "type": "HTTP",
  "ip_addresses": [
    "172.31.24.160"
  ],
  "start_time": "2025-04-15T15:05:13.411796",
  "end_time": "2025-04-15T15:05:13.416948",
  "duration": "5.151668ms",
  "body": "Hello World",
  "upstream_calls": {
    "http://localhost:9090/response": {
      "name": "Service",
      "uri": "http://localhost:9090/response",
      "type": "HTTP",
      "ip_addresses": [
        "172.31.23.5"
      ],
      "start_time": "2025-04-15T15:05:13.416041",
      "end_time": "2025-04-15T15:05:13.416130",
      "duration": "88.913µs",
      "headers": {
        "Content-Length": "270",
        "Content-Type": "text/plain; charset=utf-8",
        "Date": "Tue, 15 Apr 2025 15:05:13 GMT",
        "Server": "envoy",
        "X-Envoy-Upstream-Service-Time": "3"
      },
      "body": "Hello World",
      "code": 200
    }
  },
  "code": 200
}
```

different combimation of hello service instance and response service instance
```json
{
  "name": "Service",
  "uri": "/hello",
  "type": "HTTP",
  "ip_addresses": [
    "172.31.28.51"
  ],
  "start_time": "2025-04-15T15:08:24.544757",
  "end_time": "2025-04-15T15:08:24.550157",
  "duration": "5.40006ms",
  "body": "Hello World",
  "upstream_calls": {
    "http://localhost:9090/response": {
      "name": "Service",
      "uri": "http://localhost:9090/response",
      "type": "HTTP",
      "ip_addresses": [
        "172.31.23.5"
      ],
      "start_time": "2025-04-15T15:08:24.548950",
      "end_time": "2025-04-15T15:08:24.549033",
      "duration": "83.145µs",
      "headers": {
        "Content-Length": "270",
        "Content-Type": "text/plain; charset=utf-8",
        "Date": "Tue, 15 Apr 2025 15:08:24 GMT",
        "Server": "envoy",
        "X-Envoy-Upstream-Service-Time": "4"
      },
      "body": "Hello World",
      "code": 200
    }
  },
  "code": 200
}
```

One more combination
```json
{
  "name": "Service",
  "uri": "/hello",
  "type": "HTTP",
  "ip_addresses": [
    "172.31.24.160"
  ],
  "start_time": "2025-04-15T15:10:07.872939",
  "end_time": "2025-04-15T15:10:07.880452",
  "duration": "7.512742ms",
  "body": "Hello World",
  "upstream_calls": {
    "http://localhost:9090/response": {
      "name": "Service",
      "uri": "http://localhost:9090/response",
      "type": "HTTP",
      "ip_addresses": [
        "172.31.26.189"
      ],
      "start_time": "2025-04-15T15:10:07.878973",
      "end_time": "2025-04-15T15:10:07.879312",
      "duration": "339.33µs",
      "headers": {
        "Content-Length": "272",
        "Content-Type": "text/plain; charset=utf-8",
        "Date": "Tue, 15 Apr 2025 15:10:07 GMT",
        "Server": "envoy",
        "X-Envoy-Upstream-Service-Time": "6"
      },
      "body": "Hello World",
      "code": 200
    }
  },
  "code": 200
}
```