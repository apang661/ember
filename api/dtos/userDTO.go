package dtos

import "time"
import "github.com/google/uuid"

type GetMeResponse struct {
	ID        uuid.UUID `json:"id"`
	Username  string `json:"username"`
	DisplayName string `json:"display_name"`
	Bio     string `json:"bio"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Friend struct {
	ID        uuid.UUID `json:"id"`
	Username  string `json:"username"`
	DisplayName string `json:"display_name"`
	Bio     string `json:"bio"`
}

type GetFriendsResponse struct {
	Friends []Friend `json:"friends"`
}

type PutFriendsRequest struct {
	Status    string    `json:"status"`
}
