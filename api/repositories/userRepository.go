package repositories

import (
	"database/sql"
	"github.com/google/uuid"
)

type User struct {
	ID       uuid.UUID
	Username string
	Email    string
	Bio      string
}

func CreateUser(db *sql.DB, username string, email string, passwordHash string) (uuid.UUID, error) {
	var id uuid.UUID
	err := db.QueryRow(
		"INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING uuid",
		username, email, passwordHash,
	).Scan(&id)
	return id, err
}

// GetPasswordHashByEmail fetches the user's UUID and password_hash by email
func GetPasswordHashByEmail(db *sql.DB, email string) (uuid.UUID, string, error) {
	var id uuid.UUID
	var passwordHash string

	query := `SELECT uuid, password_hash FROM users WHERE email = $1`
	err := db.QueryRow(query, email).Scan(&id, &passwordHash)
	if err != nil {
		return uuid.Nil, "", err
	}

	return id, passwordHash, nil
}


