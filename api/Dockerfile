# Dockerfile for Go Rest API

# First stage: Build the Go application
FROM golang:1.24.0-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the Go application.
# - CGO_ENABLED=0: This builds a statically linked binary, which is crucial
#   for running it in a minimal 'scratch' or 'alpine' image without C libraries.
# - GOOS=linux: This tells Go to build the binary for a Linux environment,
#   which is what Docker containers use.
# - -o /app/main: This specifies the output path and name for the compiled binary.
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main .



# Second stage: Create a minimal image to run the Go application
FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]