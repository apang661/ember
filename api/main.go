package main

import (
	"database/sql"
	"ember/api/repositories"
	"ember/api/router"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
	db, err := sql.Open("pgx", os.Getenv("DB_SOURCE"))
	if err != nil {
		panic(fmt.Sprintf("failed to connect to database: %v", err))
	}
	defer db.Close()

	// Test the connection
	if err := db.Ping(); err != nil {
		panic(fmt.Sprintf("cannot ping database: %v", err))
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

	log.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", router.CreateRouter(userRepo)))
}
