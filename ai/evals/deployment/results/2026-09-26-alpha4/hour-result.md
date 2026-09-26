# One-hour Linux result

Run: [36244505313](https://github.com/sinduke/Daylily/actions/runs/36244505313). This is the complete results.json payload retained as Markdown so evidence-only closure does not rerun source CI. Raw JSON and time series remain in the run artifact.

```json
{
  "result": "passed",
  "duration_requested_seconds": 3600,
  "checks": {
    "untrusted_root_rejected": true,
    "wrong_hostname_rejected": true,
    "trusted_ca_and_hostname_verified": true,
    "before_faults_orders": {
      "replays": 16,
      "distinct_orders": 16,
      "idempotent_order_id": 1001
    },
    "incremental_sse_seconds": [
      0.002767193000011048,
      0.15324132699998927,
      0.303656229000012
    ],
    "disconnect_releases_stream": true,
    "database_fault": {
      "observations": {
        "a": {
          "health": 200,
          "ready": 503,
          "business": 503
        },
        "b": {
          "health": 200,
          "ready": 503,
          "business": 503
        }
      },
      "seconds": 8.914085453000098,
      "order_persisted": true
    },
    "rolling_restart": {
      "drain_seconds": 2.164417876999778,
      "stream_drain_seconds": 2.023290359999919,
      "exit_code": 0,
      "proxy_instances_during_drain": [
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b",
        "b"
      ],
      "order_persisted": true
    },
    "after_faults_orders": {
      "replays": 16,
      "distinct_orders": 16,
      "idempotent_order_id": 1018
    }
  },
  "resource_budgets": {
    "rss_absolute_kib": 524288,
    "rss_window_growth_kib": 65536,
    "idle_fd_growth": 32,
    "window_samples": 3
  },
  "phases": [
    {
      "phase": "image-build",
      "timestamp": "2026-09-26T13:15:18.256594+00:00",
      "elapsed_seconds": 36.832018156000004
    },
    {
      "phase": "topology-startup",
      "timestamp": "2026-09-26T13:20:09.938238+00:00",
      "elapsed_seconds": 328.513660819
    },
    {
      "phase": "preflight",
      "timestamp": "2026-09-26T13:20:11.892990+00:00",
      "elapsed_seconds": 330.46841129899997
    },
    {
      "phase": "baseline",
      "timestamp": "2026-09-26T13:20:12.490220+00:00",
      "elapsed_seconds": 331.065640998
    },
    {
      "phase": "steady-load",
      "timestamp": "2026-09-26T13:20:15.939594+00:00",
      "elapsed_seconds": 334.51501763699997
    },
    {
      "phase": "database-outage",
      "timestamp": "2026-09-26T13:35:15.994034+00:00",
      "elapsed_seconds": 1234.569456944
    },
    {
      "phase": "database-recovery",
      "timestamp": "2026-09-26T13:35:24.185233+00:00",
      "elapsed_seconds": 1242.760651978
    },
    {
      "phase": "steady-load",
      "timestamp": "2026-09-26T13:35:24.908195+00:00",
      "elapsed_seconds": 1243.483608601
    },
    {
      "phase": "rolling-restart",
      "timestamp": "2026-09-26T13:56:15.990308+00:00",
      "elapsed_seconds": 2494.5657288959997
    },
    {
      "phase": "steady-load",
      "timestamp": "2026-09-26T13:56:18.621143+00:00",
      "elapsed_seconds": 2497.196561839
    },
    {
      "phase": "idle-final",
      "timestamp": "2026-09-26T14:20:16.344456+00:00",
      "elapsed_seconds": 3934.91987742
    }
  ],
  "environment": {
    "python": "3.12.3",
    "host_system": "Linux",
    "host_architecture": "x86_64"
  },
  "sample_interval_seconds": 15,
  "limitations": [
    "Paced mixed traffic, not maximum throughput",
    "Resource windows are not a leak proof",
    "Loopback-published TLS ingress on an isolated Docker network",
    "Database TLS disabled only inside the private trial network"
  ],
  "revision": "1f8e0ea5f149b09cc398d302bf37c5cd63258452",
  "working_tree_dirty": false,
  "harness_sha256": "939c5d190c7865578cc633d9220952325626c4c8c3ce14d73926669f3a2c5ad3",
  "docker_version": "28.0.4",
  "topology": {
    "resource_prefix": "daylily-sustained-4e2176b71d",
    "replicas": 2,
    "database_pool_max_connections_per_replica": 4,
    "database_operation_timeout_ms": 1500,
    "shutdown_grace_ms": 2000,
    "database_tls": "disabled-on-private-network"
  },
  "ci": {
    "GITHUB_RUN_ID": "36244505313",
    "GITHUB_SHA": "1f8e0ea5f149b09cc398d302bf37c5cd63258452",
    "GITHUB_REPOSITORY": "sinduke/Daylily"
  },
  "image_acquisition": {
    "swift:6.3.2-noble": "pulled",
    "caddy@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b": "pulled",
    "postgres:17": "pulled"
  },
  "source_tree_sha256": "2e34177dd9b7dcd9301df24e8e4f6afd6414e7909b32062a19a1f49a47a557db",
  "image_source_labels": {
    "org.daylily.source-revision": "1f8e0ea5f149b09cc398d302bf37c5cd63258452",
    "org.daylily.source-tree-sha256": "2e34177dd9b7dcd9301df24e8e4f6afd6414e7909b32062a19a1f49a47a557db"
  },
  "images": [
    {
      "reference": "daylily-sustained-4e2176b71d:local",
      "id": "sha256:c377d37a5838cc9e5d248871a9982d81a2d9c740da61fadd401dd1b2f5305606",
      "digests": [],
      "architecture": "amd64",
      "os": "linux"
    },
    {
      "reference": "swift:6.3.2-noble",
      "id": "sha256:e1e1671882b89f0690ca4c69cd2982cd868b6f3ce4b34301fe8434eba997add9",
      "digests": [
        "swift@sha256:c4336909a71b2e69b884f4078cdf98c0cd081911632cb349ef72abc4cbed69fc"
      ],
      "architecture": "amd64",
      "os": "linux"
    },
    {
      "reference": "caddy@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b",
      "id": "sha256:2d8b1708bf8008935c0e2a9b6564f7f080cf9a73af3b27718f286230449b7101",
      "digests": [
        "caddy@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b"
      ],
      "architecture": "amd64",
      "os": "linux"
    },
    {
      "reference": "postgres:17",
      "id": "sha256:212aeeeb8faaef6c46498d86cbec6b9344d8d9492996b174664ff82c562ab685",
      "digests": [
        "postgres@sha256:d74eeac9a635390a49bc21bd49fccd973de707e2a53a76ac49b552b8712ec46f"
      ],
      "architecture": "amd64",
      "os": "linux"
    }
  ],
  "image_source_verified": true,
  "swift_version": "Swift version 6.3.2 (swift-6.3.2-RELEASE)\nTarget: x86_64-unknown-linux-gnu",
  "tls": {
    "version": "TLSv1.3",
    "cipher": [
      "TLS_AES_128_GCM_SHA256",
      "TLSv1.3",
      128
    ],
    "hostname": "localhost",
    "certificate_sha256": "1c1cc74d4ba294ec058f087bb9754f76adce3ced1ab40ebbaa7411fdc9d24627",
    "public_root_sha256": "6d429a7d356e01bc16ef94a55506f173252d639ec959261ccf010ca28a69af77"
  },
  "sustained": {
    "seconds": 3600.174521409,
    "workers": 4,
    "pace_seconds": 0.05,
    "requests_succeeded": 223821,
    "expected_database_503": 20,
    "unexpected_failures": [],
    "p50_ms": 4.0857799999685085,
    "p95_ms": 44.44183400028123
  },
  "database_fault_windows": [
    {
      "start": 1265.686453651,
      "end": 1274.600539104,
      "started_at": "2026-09-26T13:35:15.994084+00:00",
      "ended_at": "2026-09-26T13:35:24.908183+00:00"
    }
  ],
  "metrics_after": {
    "a": {
      "activeRequests": 1,
      "activeStreams": 0,
      "cancelled": 0,
      "failed": 0,
      "completed": 50836,
      "completedRequests": 50836,
      "instance": "a"
    },
    "b": {
      "activeStreams": 0,
      "completed": 126775,
      "failed": 0,
      "cancelled": 6,
      "activeRequests": 1,
      "completedRequests": 126781,
      "instance": "b"
    }
  },
  "resource_summary": {
    "process_generations": [
      {
        "instance": "a",
        "generation": 0,
        "samples": 147,
        "window_samples": 3,
        "first_window_rss_median_kib": 33016,
        "last_window_rss_median_kib": 36240,
        "rss_growth_kib": 3224,
        "peak_rss_kib": 36244,
        "peak_fd_count": 41,
        "first_window_fd_median": 41,
        "last_window_fd_median": 38,
        "fd_growth_within_generation": -3,
        "peak_tcp_established": 7,
        "peak_threads": 15,
        "idle_fd_growth_across_trial": 1
      },
      {
        "instance": "a",
        "generation": 1,
        "samples": 99,
        "window_samples": 3,
        "first_window_rss_median_kib": 33200,
        "last_window_rss_median_kib": 35328,
        "rss_growth_kib": 2128,
        "peak_rss_kib": 35328,
        "peak_fd_count": 42,
        "first_window_fd_median": 37,
        "last_window_fd_median": 42,
        "fd_growth_within_generation": 5,
        "peak_tcp_established": 8,
        "peak_threads": 15,
        "idle_fd_growth_across_trial": 1
      },
      {
        "instance": "b",
        "generation": 0,
        "samples": 247,
        "window_samples": 3,
        "first_window_rss_median_kib": 32220,
        "last_window_rss_median_kib": 35952,
        "rss_growth_kib": 3732,
        "peak_rss_kib": 35952,
        "peak_fd_count": 41,
        "first_window_fd_median": 41,
        "last_window_fd_median": 41,
        "fd_growth_within_generation": 0,
        "peak_tcp_established": 7,
        "peak_threads": 16,
        "idle_fd_growth_across_trial": 0
      }
    ],
    "samples": 494,
    "planned_restart_gaps": [
      {
        "timestamp": "2026-09-26T13:56:15.954798+00:00",
        "elapsed_seconds": 2494.5302188399996,
        "phase": "steady-load",
        "instance": "a",
        "generation": 0,
        "container_host_pid": 6380,
        "process_started_at": "2026-09-26T13:20:10.994895054Z",
        "rss_kib": 36248,
        "threads": 15,
        "fd_count": 36,
        "tcp_entries": 13,
        "tcp_established": 3,
        "sample_error": "Remote end closed connection without response",
        "planned_restart_gap": true,
        "planned_restart_in_progress": true
      }
    ],
    "unexpected_sampling_errors": []
  },
  "cleanup_errors": [],
  "total_seconds": 3939.4715297519997,
  "resource_sampling_errors": []
}
```
