# syntax=docker/dockerfile:1

FROM golang:1.24-bookworm AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/planner .

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
ENV PORT=8080
EXPOSE 8080
COPY --from=builder /out/planner /planner
USER nonroot:nonroot
ENTRYPOINT ["/planner"]
