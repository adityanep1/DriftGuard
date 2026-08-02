"""Small observable service used by the DriftGuard progressive-delivery path."""

import logging
import os
import time
from contextlib import asynccontextmanager
from threading import Event

from fastapi import FastAPI, Response, status
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

try:  # Optional in local unit tests; enabled in the image.
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter
    from opentelemetry import trace
except ImportError:  # pragma: no cover - exercised when optional OTel deps are absent
    FastAPIInstrumentor = None
    trace = None

logger = logging.getLogger("driftguard.demo")
requests_total = Counter("demo_service_requests_total", "Total work requests", ["route"])
http_requests_total = Counter("http_requests_total", "HTTP requests", ["service", "status"])
http_request_duration = Histogram("http_request_duration_seconds", "HTTP request duration", ["service"])
ready = Event()


def configure_telemetry() -> None:
    if trace is None:
        return
    resource = Resource.create({"service.name": os.getenv("OTEL_SERVICE_NAME", "demo-service")})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)


@asynccontextmanager
async def lifespan(_: FastAPI):
    configure_telemetry()
    ready.set()
    logger.info("demo service is ready")
    try:
        yield
    finally:
        ready.clear()


app = FastAPI(title="DriftGuard Demo Service", version="1.0.0", lifespan=lifespan)
if FastAPIInstrumentor is not None:  # pragma: no cover - depends on optional package
    FastAPIInstrumentor.instrument_app(app)


@app.middleware("http")
async def observe_requests(request, call_next):
    started = time.perf_counter()
    response = await call_next(request)
    elapsed = time.perf_counter() - started
    http_requests_total.labels(service="demo-service", status=str(response.status_code)).inc()
    http_request_duration.labels(service="demo-service").observe(elapsed)
    return response


@app.get("/healthz")
def healthz(response: Response):
    if not ready.is_set():
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready"}
    return {"status": "ready"}


@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
def work():
    started = time.perf_counter()
    requests_total.labels(route="/").inc()
    result = {"service": "demo-service", "message": "work complete"}
    logger.info("work request completed in %.3fms", (time.perf_counter() - started) * 1000)
    return result
