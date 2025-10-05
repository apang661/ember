package main

import (
	"encoding/json"
	"log"
	"net/http"
	"ember/api/handlers"
	"ember/api/auth"
	"database/sql"
    "fmt"
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

	//JWT test
	id := uuid.New()
	token, err := auth.GenerateJWT(id)
	uuid, err := auth.ValidateJWT(token)
	if id == uuid {
		log.Println("jwt works")
	}

	// Test endpoint
	http.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "Hello, world!",
		})
	})

	http.HandleFunc("/auth/register", handlers.RegisterHandler(db))
	http.HandleFunc("/auth/login", handlers.LoginHandler(db))
	// http.HandleFunc("/me", handlers.MeHandler)
	// http.HandleFunc("/me/friends", handlers.FriendsHandler)
	// http.HandleFunc("/pins", handlers.PinsHandler)

	log.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}