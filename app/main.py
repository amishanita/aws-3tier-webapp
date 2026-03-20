import json
import os
import threading
import time
from typing import Any, Dict, Optional, Tuple

import boto3
import mysql.connector
import redis
from flask import Flask, jsonify, request
from pythonjsonlogger import jsonlogger


def _env_int(name: str, default: int) -> int:
    v = os.getenv(name)
    if not v:
        return default
    return int(v)


def _create_logger() -> Any:
    import logging

    logger = logging.getLogger("tier-ha-web")
    logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))
    # Avoid duplicate handlers in case of gunicorn workers.
    if logger.handlers:
        return logger

    handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter("%(levelname)s %(name)s %(message)s %(asctime)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger


logger = _create_logger()

app = Flask(__name__)


class AppState:
    def __init__(self) -> None:
        self.cache_hits = 0
        self.cache_misses = 0
        self.api_response_time_ms_sum = 0.0
        self.api_response_time_ms_count = 0
        self.error_count = 0
        self._lock = threading.Lock()
        self.stop = False

        self.metrics_namespace = os.getenv("METRICS_NAMESPACE", "TierHaWeb")
        self.aws_region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or "us-east-1"
        self.metrics_interval_seconds = _env_int("METRICS_INTERVAL_SECONDS", 30)

        self.secrets_client = boto3.client("secretsmanager", region_name=self.aws_region)
        self.cw_client = boto3.client("cloudwatch", region_name=self.aws_region)

        self.db_secret_arn = os.environ["DB_SECRET_ARN"]
        self.redis_endpoint = os.environ["REDIS_ENDPOINT"]  # host:port
        self.cache_ttl_seconds = _env_int("CACHE_TTL_SECONDS", 120)

        self._db_conn = None
        self._redis = None

    def _get_db_creds(self) -> Dict[str, Any]:
        resp = self.secrets_client.get_secret_value(SecretId=self.db_secret_arn)
        secret_str = resp.get("SecretString")
        if not secret_str:
            raise RuntimeError("DB secret is missing SecretString")
        return json.loads(secret_str)

    def get_redis(self) -> redis.Redis:
        if self._redis is None:
            secret = self._get_db_creds()
            password = secret.get("redis_password") or None
            host, port_s = self.redis_endpoint.split(":")
            self._redis = redis.Redis(host=host, port=int(port_s), password=password, decode_responses=True)
        return self._redis

    def get_db(self) -> mysql.connector.MySQLConnection:
        if self._db_conn is None or not self._db_conn.is_connected():
            secret = self._get_db_creds()
            self._db_conn = mysql.connector.connect(
                host=secret["db_host"],
                port=int(secret.get("db_port", 3306)),
                user=secret["db_username"],
                password=secret["db_password"],
                database=secret.get("db_name", "appdb"),
                connection_timeout=5,
            )
        return self._db_conn

    def ensure_schema(self) -> None:
        # Minimal bootstrap: create a KV table if it doesn't exist.
        conn = self.get_db()
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS kv_store (
              cache_key VARCHAR(255) PRIMARY KEY,
              cache_value TEXT NOT NULL,
              updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
            """
        )
        conn.commit()
        cur.close()

    def bump_cache_hit(self) -> None:
        with self._lock:
            self.cache_hits += 1

    def bump_cache_miss(self) -> None:
        with self._lock:
            self.cache_misses += 1

    def bump_api_timing(self, duration_ms: float) -> None:
        with self._lock:
            self.api_response_time_ms_sum += duration_ms
            self.api_response_time_ms_count += 1

    def bump_error(self) -> None:
        with self._lock:
            self.error_count += 1

    def publish_metrics(self) -> None:
        with self._lock:
            hits = self.cache_hits
            misses = self.cache_misses
            total = hits + misses
            avg_resp_ms = (
                (self.api_response_time_ms_sum / self.api_response_time_ms_count)
                if self.api_response_time_ms_count
                else 0.0
            )
            errors = self.error_count

            # reset counters
            self.cache_hits = 0
            self.cache_misses = 0
            self.api_response_time_ms_sum = 0.0
            self.api_response_time_ms_count = 0
            self.error_count = 0

        dimensions = []
        if os.getenv("APP_INSTANCE_ID"):
            dimensions = [{"Name": "InstanceId", "Value": os.getenv("APP_INSTANCE_ID")}]

        hit_rate = (hits / total) if total else 0.0
        # CloudWatch requires numbers; publish as percent.
        try:
            self.cw_client.put_metric_data(
                Namespace=self.metrics_namespace,
                MetricData=[
                    {"MetricName": "CacheHitRate", "Value": hit_rate * 100.0, "Unit": "Percent", "Dimensions": dimensions},
                    {"MetricName": "ApiResponseTimeMsAvg", "Value": avg_resp_ms, "Unit": "Milliseconds", "Dimensions": dimensions},
                    {"MetricName": "ApiErrors", "Value": errors, "Unit": "Count", "Dimensions": dimensions},
                ],
            )
        except Exception as e:
            logger.warning("Failed to publish metrics", extra={"error": str(e)})

    def run_metrics_loop(self) -> None:
        while not self.stop:
            time.sleep(self.metrics_interval_seconds)
            self.publish_metrics()


state: Optional[AppState] = None
_init_lock = threading.Lock()
_initialized = False


@app.before_request
def init_app() -> None:
    """
    Lazy initialization for dependency clients.
    Flask 3 removed `before_first_request`, so we use a guarded `before_request`.
    """
    global state, _initialized
    if _initialized:
        return

    with _init_lock:
        if _initialized:
            return
        try:
            state = AppState()
            state.ensure_schema()
            logger.info("Schema ensured")
        except Exception as e:
            # Don't hard-fail: health checks can still work, and we'll fail cache/data endpoints.
            logger.exception("App initialization failed", extra={"error": str(e)})
            state = None

        if state is not None:
            threading.Thread(target=state.run_metrics_loop, daemon=True).start()

        _initialized = True


@app.get("/health")
def health() -> Any:
    return jsonify({"status": "ok"})


def _get_cached_value(key: str) -> Tuple[bool, Optional[str]]:
    assert state is not None
    r = state.get_redis()
    cached = r.get(f"kv:{key}")
    if cached is None:
        return False, None
    return True, cached


def _get_value_from_db(key: str) -> str:
    assert state is not None
    conn = state.get_db()
    cur = conn.cursor()
    cur.execute("SELECT cache_value FROM kv_store WHERE cache_key=%s", (key,))
    row = cur.fetchone()
    if not row:
        # Seed value deterministically so load tests can hit consistent data.
        value = f"value-for-{key}"
        cur.execute("INSERT INTO kv_store (cache_key, cache_value) VALUES (%s, %s)", (key, value))
        conn.commit()
    else:
        value = row[0]
    cur.close()
    return value


@app.get("/api/data")
def api_data() -> Any:
    global state
    if state is None:
        return jsonify({"error": "app not initialized"}), 503

    start = time.time()
    key = request.args.get("key", "default")

    try:
        hit, cached = _get_cached_value(key)
        if hit and cached is not None:
            state.bump_cache_hit()
            duration_ms = (time.time() - start) * 1000.0
            state.bump_api_timing(duration_ms)
            return jsonify({"key": key, "value": cached, "cache": "hit"})

        # Cache miss: read from DB, then set Redis.
        state.bump_cache_miss()
        value = _get_value_from_db(key)
        r = state.get_redis()
        r.set(f"kv:{key}", value, ex=state.cache_ttl_seconds)

        duration_ms = (time.time() - start) * 1000.0
        state.bump_api_timing(duration_ms)
        return jsonify({"key": key, "value": value, "cache": "miss"})
    except Exception as e:
        if state is not None:
            state.bump_error()
        duration_ms = (time.time() - start) * 1000.0
        logger.exception("api_data failed", extra={"error": str(e), "duration_ms": duration_ms})
        return jsonify({"error": "internal_error"}), 500


if __name__ == "__main__":
    # For local development only.
    app.run(host="0.0.0.0", port=5000, debug=False)

