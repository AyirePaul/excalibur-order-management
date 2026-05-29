from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from app.core.config import get_settings


def setup_telemetry(app=None) -> None:
    settings = get_settings()
    resource = Resource.create({
        "service.name": settings.otel_service_name,
        "deployment.environment": settings.app_env,
    })

    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(
            endpoint=f"{settings.otel_exporter_otlp_endpoint}/v1/traces"
        ))
    )
    trace.set_tracer_provider(tracer_provider)

    metric_reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=f"{settings.otel_exporter_otlp_endpoint}/v1/metrics")
    )
    meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    metrics.set_meter_provider(meter_provider)

    # instrument_app(app) instruments only this specific FastAPI instance so
    # repeated calls in tests (each with a new app instance) don't re-instrument
    # a global and swallow the RuntimeError on the second call.
    if app is not None:
        FastAPIInstrumentor.instrument_app(app)

    from app.db.base import get_engine
    try:
        SQLAlchemyInstrumentor().instrument(engine=get_engine())
    except Exception:  # noqa: BLE001,S110
        pass  # already instrumented (e.g., second app instance in tests)


def get_tracer() -> trace.Tracer:
    return trace.get_tracer("orders-api")
