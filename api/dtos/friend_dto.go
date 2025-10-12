package dtos

import (
	"github.com/google/uuid"
)

type Friend struct {
	ID          uuid.UUID `json:"id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
	Bio         string    `json:"bio"`
}

type FriendRequest struct {
	ID          uuid.UUID `json:"id"`
	Username    string    `json:"username"`
	DisplayName string    `json:"display_name"`
}

type GetFriendsResponse struct {
	Friends []Friend `json:"friends"`
}

type GetFriendRequestsResponse struct {
	Incoming []FriendRequest `json:"incoming_requests"`
	Outgoing []FriendRequest `json:"outgoing_requests"`
}

type PatchFriendRequestsRequest struct {
	Status string `json:"status"`
}
