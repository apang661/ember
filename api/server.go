package main

import (
	"database/sql"
	"ember/api/auth"
	"ember/api/repositories"
	"ember/api/router"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	dsn := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s",
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_NAME"),
	)

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		panic(fmt.Sprintf("failed to connect to database: %v", err))
	}
	defer db.Close()

	// Test the connection
	if err := db.Ping(); err != nil {
		panic(fmt.Sprintf("cannot ping database: %v", err))
	}

	fmt.Println("Successfully connected to PostgreSQL!")

	// id1
	id, err := uuid.Parse("56e6af3d-eabf-41e6-b88c-9c122f72b9cd")
	jwt, err := auth.GenerateJWT(id)
	log.Println(jwt)

	// id2
	id, err = uuid.Parse("becf5685-4771-425f-80be-f8c0da7c3fef")
	jwt, err = auth.GenerateJWT(id)
	log.Println(jwt)

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
