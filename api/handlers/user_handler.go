package handlers

import (
	"encoding/json"
	"net/http"

	"ember/api/dtos"
	"ember/api/repositories"
	"log"

	"github.com/google/uuid"
)

// GET /me
func GetMeHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Get user id from context
		userID := r.Context().Value("userID").(uuid.UUID)

		user, err := userRepo.GetUserByUUID(userID)
		if err != nil {
			log.Println(err)
			http.Error(w, "Unable to retrieve user data", http.StatusInternalServerError)
			return
		}

		resp := dtos.GetMeResponse{
			ID:        user.ID,
			Username:  user.Username,
			CreatedAt: user.CreatedAt,
			UpdatedAt: user.UpdatedAt,
		}

		if user.DisplayName.Valid {
			resp.DisplayName = user.DisplayName.String
		}

		if user.Bio.Valid {
			resp.Bio = user.Bio.String
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// GET /users with query params for searching users

// GET /users/{userID}
