package telemetry

import (
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

// NewTracerProvider はトレーサーを初期化してJaegerに接続する
// endpoint: Jaegerのアドレス（例: "localhost:4318"）
func NewTracerProvider(ctx context.Context, endpoint string) (*sdktrace.TracerProvider, error) {
	// JaegerにOTLP形式でトレースを送信するExporterを作成
	exp, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(), // ローカルなのでTLSなし
	)
	if err != nil {
		return nil, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp), // トレースをまとめて送信
		sdktrace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String("my-kanban-app"), // Jaeger UI上での表示名
		)),
	)
	otel.SetTracerProvider(tp) // グローバルなTracerProviderとして登録
	return tp, nil
}
