# Build stage
FROM golang:1.27-alpine AS builder

WORKDIR /app

# 依存関係をインストール
RUN apk add --no-cache git

# Go モジュールをコピーしてダウンロード
COPY go.mod go.sum ./
RUN go mod download

# ソースコードをコピー
COPY . .

# バイナリをビルド
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app cmd/api/main.go

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# ビルドステージからバイナリをコピー
COPY --from=builder /app/app .
COPY .env .

EXPOSE 8080

CMD ["./app"]
