package models

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
)

type Location struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Pin struct {
	UserID     uuid.UUID      `json:"user_id"`
	Emotion    string         `json:"emotion"`
	Message    sql.NullString `json:"message,omitempty"`
	Location   Location       `json:"location"`
	Visibility string         `json:"visibility"`
	CreatedAt  time.Time      `json:"created_at"`
	ExpiresAt  sql.NullTime   `json:"expires_at,omitempty"`
}
