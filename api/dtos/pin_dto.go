package dtos

import "github.com/google/uuid"
import "time"

type CreatePinRequest struct {
	Emotion    string  `json:"emotion"`
	Message    string  `json:"message"`
	Longitude  float64 `json:"longitude"`
	Latitude   float64 `json:"latitude"`
	Visibility string  `json:"visibility"`
}

type Pin struct {
	UserID    uuid.UUID `json:"user_id"`
	Emotion   string    `json:"emotion"`
	Message   string    `json:"message"`
	Longitude float64   `json:"longitude"`
	Latitude  float64   `json:"latitude"`
	CreatedAt time.Time `json:"created_at"`
}

type GetPinListResponse struct {
	Pins []Pin `json:"pins"`
}
