# syntax=docker/dockerfile:1
FROM golang:1.21 as builder
WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o planner main.go

FROM gcr.io/distroless/base-debian12
WORKDIR /
COPY --from=builder /app/planner /planner
EXPOSE 8080
ENTRYPOINT ["/planner"] 