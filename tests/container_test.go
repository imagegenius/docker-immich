package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"io"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/network"
	"github.com/testcontainers/testcontainers-go/wait"

	helpers "github.com/hydazz/containers/tests"
)

const postgresImage = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0"

// tiffFixture is a 1x1 uncompressed grayscale TIFF.
const tiffFixture = "TU0AKgAAACgAAqACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAAA/wAQAQAAAwAAAAEAAQAAAQEAAwAAAAEAAQAAAQIAAwAAAAIACAAIAQMAAwAAAAEAAQAAAQYAAwAAAAEAAQAAAQoAAwAAAAEAAQAAAREABAAAAAEAAAAmARIAAwAAAAEAAQAAARUAAwAAAAEAAgAAARYAAwAAAAEAAQAAARcABAAAAAEAAAACARwAAwAAAAEAAQAAASgAAwAAAAEAAgAAAVIAAwAAAAEAAgAAAVMAAwAAAAIAAQABh2kABAAAAAEAAAAIAAAAAA=="

func TestSharpDecodesTIFF(t *testing.T) {
	ctx := context.Background()
	image := helpers.GetTestImage("immich:local-main")

	fixture, err := base64.StdEncoding.DecodeString(tiffFixture)
	require.NoError(t, err)

	container, err := testcontainers.Run(ctx, image,
		testcontainers.WithEntrypoint("node"),
		testcontainers.WithEntrypointArgs(
			"-e",
			`const sharp = require("/app/immich/server/node_modules/sharp");
sharp("/tmp/sample.tiff").jpeg().toBuffer({ resolveWithObject: true })
  .then(({ info: { width, height } }) => {
    if (width !== 1 || height !== 1) {
      throw new Error("unexpected dimensions: " + width + "x" + height);
    }
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });`,
		),
		testcontainers.WithFiles(testcontainers.ContainerFile{
			Reader:            bytes.NewReader(fixture),
			ContainerFilePath: "/tmp/sample.tiff",
			FileMode:          0o644,
		}),
		testcontainers.WithWaitStrategy(wait.ForExit()),
	)
	testcontainers.CleanupContainer(t, container)
	require.NoError(t, err)

	state, err := container.State(ctx)
	require.NoError(t, err)

	logs, err := container.Logs(ctx)
	require.NoError(t, err)
	defer logs.Close()

	logBytes, err := io.ReadAll(logs)
	require.NoError(t, err)
	require.Equal(t, 0, state.ExitCode, "Sharp should decode TIFF images:\n%s", logBytes)
}

func Test(t *testing.T) {
	ctx := context.Background()
	variant := os.Getenv("VARIANT")
	if variant == "" {
		variant = "main"
	}
	image := helpers.GetTestImage("immich:local-" + variant)
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

	logs, err := immich.Logs(ctx)
	require.NoError(t, err)
	defer logs.Close()

	logBytes, err := io.ReadAll(logs)
	require.NoError(t, err)
	require.NotContains(t, string(logBytes), "cannot be preloaded")
}
