//go:build integration

package setup_test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/redis/go-redis/v9"
)

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func pingPostgres(ctx context.Context, t *testing.T) error {
	conn, err := pgx.Connect(ctx, envOr("PG_DSN", "postgres://lab:lab@localhost:5432/lab"))
	if err != nil {
		return err
	}
	defer func() { _ = conn.Close(ctx) }() // read-only check: a close error changes nothing

	var version string
	if err := conn.QueryRow(ctx, "SHOW server_version").Scan(&version); err != nil {
		return err
	}
	t.Logf("postgres %s", version)
	return nil
}

func pingRedis(ctx context.Context, t *testing.T) error {
	rdb := redis.NewClient(&redis.Options{Addr: envOr("REDIS_ADDR", "localhost:6379")})
	defer func() { _ = rdb.Close() }()

	info, err := rdb.Info(ctx, "server").Result()
	if err != nil {
		return err
	}
	t.Logf("redis reachable (%d bytes of INFO server)", len(info))
	return nil
}

func TestCoreInfraReachable(t *testing.T) {
	tests := []struct {
		name string
		ping func(context.Context, *testing.T) error
	}{
		{"postgres", pingPostgres},
		{"redis", pingRedis},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
			defer cancel()

			if err := tc.ping(ctx, t); err != nil {
				t.Fatalf("%s unreachable (did you run `make up`?): %v", tc.name, err)
			}
		})
	}
}
