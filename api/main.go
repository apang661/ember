package main

import (
    "context"
    "database/sql"
    "ember/api/repositories"
    "ember/api/router"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"

    _ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
    dsn := os.Getenv("DB_SOURCE")
    if dsn == "" {
        log.Fatal("DB_SOURCE is not set")
    }

    db, err := sql.Open("pgx", dsn)
    if err != nil {
        log.Fatalf("failed to open database: %v", err)
    }
    defer db.Close()

    // Robust retry: wait up to ~60s for DB to be ready
    if err := waitForDB(db, 60*time.Second); err != nil {
        log.Fatalf("cannot ping database after retries: %v", err)
    }

	fmt.Println("Successfully connected to PostgreSQL!")

	// Test endpoint
	http.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "Hello, world!",
		})
	})

    userRepo := repositories.NewUserRepository(db)
	pinRepo := repositories.NewPinRepository(db)

	log.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", router.CreateRouter(userRepo, pinRepo)))
}

// waitForDB attempts to Ping the DB with exponential backoff until the timeout elapses.
func waitForDB(db *sql.DB, timeout time.Duration) error {
    deadline := time.Now().Add(timeout)
    backoff := 500 * time.Millisecond
    for {
        ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
        err := db.PingContext(ctx)
        cancel()
        if err == nil {
            return nil
        }
        if time.Now().After(deadline) {
            return fmt.Errorf("timeout waiting for DB: %w", err)
        }
        // Log only connection-level errors succinctly
        var netErr error = err
        log.Printf("Waiting for database... (%v)\n", netErr)
        time.Sleep(backoff)
        if backoff < 5*time.Second {
            backoff *= 2
        }
    }
}
