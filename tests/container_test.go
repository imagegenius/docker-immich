package main

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/network"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/imagegenius/docker-immich/tests/testhelpers"
)

const postgresImage = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0"

func Test(t *testing.T) {
	ctx := context.Background()
	variant := os.Getenv("VARIANT")
	if variant == "" {
		variant = "main"
	}
	image := testhelpers.GetTestImage("immich:local-" + variant)
	t.Logf("testing image: %s", image)

	net, err := network.New(ctx)
	require.NoError(t, err)
	t.Cleanup(func() { _ = net.Remove(ctx) })

	pg, err := testcontainers.Run(ctx, postgresImage,
		testcontainers.WithEnv(map[string]string{
			"POSTGRES_USER":        "immich",
			"POSTGRES_PASSWORD":    "immich",
			"POSTGRES_DB":          "immich",
			"POSTGRES_INITDB_ARGS": "--data-checksums",
		}),
		network.WithNetwork([]string{"postgres"}, net),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(2*time.Minute),
		),
	)
	testcontainers.CleanupContainer(t, pg)
	require.NoError(t, err, "postgres failed to start")

	rd, err := testcontainers.Run(ctx, "valkey/valkey:8-bookworm",
		network.WithNetwork([]string{"redis"}, net),
		testcontainers.WithWaitStrategy(wait.ForListeningPort("6379/tcp")),
	)
	testcontainers.CleanupContainer(t, rd)
	require.NoError(t, err, "valkey failed to start")

	immich, err := testcontainers.Run(ctx, image,
		testcontainers.WithEnv(map[string]string{
			"DB_HOSTNAME":      "postgres",
			"DB_USERNAME":      "immich",
			"DB_PASSWORD":      "immich",
			"DB_DATABASE_NAME": "immich",
			"REDIS_HOSTNAME":   "redis",
		}),
		testcontainers.WithExposedPorts("8080/tcp"),
		network.WithNetwork([]string{"immich"}, net),
		testcontainers.WithWaitStrategy(
			wait.ForHTTP("/api/server/ping").
				WithPort("8080/tcp").
				WithStartupTimeout(3*time.Minute),
		),
	)
	testcontainers.CleanupContainer(t, immich)
	require.NoError(t, err, "immich failed to come up; check DB+Redis reachability and logs above")
}
