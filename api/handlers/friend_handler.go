package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"ember/api/dtos"
	"ember/api/repositories"
	"log"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

// --- FRIENDS ---

// GET /friends
func GetFriendsHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		// Query database for friends information
		friendsList, err := userRepo.GetFriendsByUUID(userID)
		if err != nil {
			log.Println(err)
			http.Error(w, "Unable to query friends data", http.StatusInternalServerError)
		}

		var resp dtos.GetFriendsResponse
		resp.Friends = []dtos.Friend{}
		for _, v := range friendsList {
			friend := dtos.Friend{
				ID:       v.ID,
				Username: v.Username,
			}

			if v.DisplayName.Valid {
				friend.DisplayName = v.DisplayName.String
			}

			if v.Bio.Valid {
				friend.Bio = v.Bio.String
			}

			resp.Friends = append(resp.Friends, friend)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// DELETE /friends/{friendID}
func DeleteFriendsHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		friendIDStr := chi.URLParam(r, "friendID")
		friendID, err := uuid.Parse(friendIDStr)
		if err != nil {
			http.Error(w, "invalid friend ID", http.StatusBadRequest)
			return
		}

		success, err := userRepo.DeleteFriend(userID, friendID)
		if err != nil {
			http.Error(w, "unable to delete friend", http.StatusInternalServerError)
			return
		}

		if !success {
			http.Error(w, "friend does not exist", http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusOK)
	}
}

// --- FRIEND REQUESTS ---

// POST /friends/requests/{friendID}
func PostFriendRequestsHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		friendIDStr := chi.URLParam(r, "friendID")
		friendID, err := uuid.Parse(friendIDStr)
		if err != nil {
			http.Error(w, "invalid friend ID", http.StatusBadRequest)
			return
		}

		if userID == friendID {
			http.Error(w, "cannot send friend request to yourself", http.StatusBadRequest)
			return
		}

		success, err := userRepo.CreateFriendRequest(userID, friendID)
		if err != nil {
			if errors.Is(err, repositories.ErrTargetUserNotFound) {
				http.Error(w, "target user does not exist", http.StatusBadRequest)
				return
			}
			log.Printf("Error creating friend request from %s to %s: %v", userID, friendID, err)
			http.Error(w, "unable to send friend request", http.StatusInternalServerError)
			return
		}

		if !success {
			http.Error(w, "friendship already exists or is pending", http.StatusBadRequest)
			return
		}

		w.WriteHeader(http.StatusOK)
	}
}

// GET /friends/requests
func GetFriendRequestsHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		// Query database for friends information
		incomingList, outgoingList, err := userRepo.GetFriendRequestsByUUID(userID)
		if err != nil {
			log.Println(err)
			http.Error(w, "Unable to query friend requests data", http.StatusInternalServerError)
		}

		var resp dtos.GetFriendRequestsResponse
		resp.Incoming = []dtos.FriendRequest{}
		resp.Outgoing = []dtos.FriendRequest{}
		for _, v := range incomingList {
			request := dtos.FriendRequest{
				ID:       v.ID,
				Username: v.Username,
			}

			if v.DisplayName.Valid {
				request.DisplayName = v.DisplayName.String
			}

			resp.Incoming = append(resp.Incoming, request)
		}

		for _, v := range outgoingList {
			request := dtos.FriendRequest{
				ID:       v.ID,
				Username: v.Username,
			}

			if v.DisplayName.Valid {
				request.DisplayName = v.DisplayName.String
			}

			resp.Outgoing = append(resp.Outgoing, request)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// PATCH /friends/requests/{friendID}
func PatchFriendRequestsHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		friendIDStr := chi.URLParam(r, "friendID")
		friendID, err := uuid.Parse(friendIDStr)
		if err != nil {
			http.Error(w, "invalid friend ID", http.StatusBadRequest)
			return
		}

		var req dtos.PatchFriendRequestsRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if userID == friendID {
			http.Error(w, "cannot update friendship with yourself", http.StatusBadRequest)
			return
		}

		switch req.Status {
		case "accepted":
			success, err := userRepo.AcceptFriendRequest(userID, friendID)
			if err != nil {
				log.Println(err)
				http.Error(w, "unable to accept friend request", http.StatusInternalServerError)
				return
			}
			if !success {
				http.Error(w, "no pending friend request from this user", http.StatusBadRequest)
				return
			}

		case "rejected":
			success, err := userRepo.RejectFriendRequest(userID, friendID)
			if err != nil {
				http.Error(w, "unable to reject friend request", http.StatusInternalServerError)
				return
			}
			if !success {
				http.Error(w, "no pending friend request from this user", http.StatusBadRequest)
				return
			}
		default:
			http.Error(w, "unsupported status", http.StatusBadRequest)
			return
		}

		// Success
		w.WriteHeader(http.StatusOK)
	}
}
