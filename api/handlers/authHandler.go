package handlers

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"

	"golang.org/x/crypto/bcrypt"

	"ember/api/auth"
	"ember/api/dtos"
	"ember/api/repositories"

	"github.com/google/uuid"
)

// POST /auth/register
func PostRegisterHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dtos.RegisterRequest

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// send to database
		var id uuid.UUID
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "unable to hash", http.StatusBadRequest)
		}

		id, err = userRepo.CreateUser(req.Username, req.Email, string(hash))
		if err != nil {
			log.Println(err)
			http.Error(w, "unable to create user", http.StatusBadRequest)
			return
		}

		resp := dtos.RegisterResponse{
			UserID: id,
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(resp)
	}
}

// POST /auth/login
func PostLoginHandler(userRepo repositories.UserRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dtos.LoginRequest

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Fetch user uuid and user password from DB
		id, hash, err := userRepo.GetPasswordHashByEmail(req.Email)
		if err != nil {
			if err == sql.ErrNoRows {
				http.Error(w, "invalid credentials", http.StatusUnauthorized)
			} else {
				log.Println(err)
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
			return
		}

		// Compare passwords
		if err = bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)); err != nil {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}

		// Generate JWT
		jwt, err := auth.GenerateJWT(id)
		if err != nil {
			log.Println(err)
			http.Error(w, "JWT failure", http.StatusInternalServerError)
			return
		}

		// Return success response with a mock token
		resp := dtos.LoginResponse{
			Token: jwt,
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(resp)
	}
}
