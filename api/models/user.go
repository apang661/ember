package models

import (
	"database/sql"
	"github.com/google/uuid"
	"time"
)

type User struct {
	ID          uuid.UUID      `json:"id"`
	Username    string         `json:"username"`
	DisplayName sql.NullString `json:"display_name"`
	Bio         sql.NullString `json:"bio"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
}
