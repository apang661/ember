package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"ember/api/dtos"
	"ember/api/repositories"

	"github.com/google/uuid"
)

const maxNearbyRadiusKm = 25.0

func GetPinsFriendsHandler(pinRepo repositories.PinRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		pins, err := pinRepo.QueryFriendPins(userID)
		if err != nil {
			log.Println("query friend pins:", err)
			http.Error(w, "unable to fetch pins", http.StatusInternalServerError)
			return
		}

		resp := dtos.GetPinListResponse{Pins: make([]dtos.Pin, 0, len(pins))}
		for _, pin := range pins {
			p := dtos.Pin{
				UserID:    pin.UserID,
				Emotion:   pin.Emotion,
				Longitude: pin.Location.Longitude,
				Latitude:  pin.Location.Latitude,
				CreatedAt: pin.CreatedAt,
			}
			if pin.Message.Valid {
				p.Message = pin.Message.String
			}
			resp.Pins = append(resp.Pins, p)
		}

		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			log.Println("encode friend pins response:", err)
		}
	}
}

func GetPinsNearbyHandler(pinRepo repositories.PinRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query()
		required := map[string]string{
			"longitude": query.Get("longitude"),
			"latitude":  query.Get("latitude"),
			"radius_km": query.Get("radius_km"),
		}

		for key, val := range required {
			if val == "" {
				http.Error(w, "missing required query parameter: "+key, http.StatusBadRequest)
				return
			}
		}

		longitude, err := strconv.ParseFloat(required["longitude"], 64)
		if err != nil {
			http.Error(w, "invalid longitude", http.StatusBadRequest)
			return
		}

		latitude, err := strconv.ParseFloat(required["latitude"], 64)
		if err != nil {
			http.Error(w, "invalid latitude", http.StatusBadRequest)
			return
		}

		radiusKm, err := strconv.ParseFloat(required["radius_km"], 64)
		if err != nil {
			http.Error(w, "invalid radius_km", http.StatusBadRequest)
			return
		}
		if radiusKm < 0 {
			http.Error(w, "radius_km must be non-negative", http.StatusBadRequest)
			return
		}
		if radiusKm > maxNearbyRadiusKm {
			radiusKm = maxNearbyRadiusKm
		}

		userID := r.Context().Value("userID").(uuid.UUID)
		pins, err := pinRepo.QueryNearbyPins(userID, longitude, latitude, radiusKm)
		if err != nil {
			log.Println("query nearby pins:", err)
			http.Error(w, "unable to fetch pins", http.StatusInternalServerError)
			return
		}

		resp := dtos.GetPinListResponse{Pins: make([]dtos.Pin, 0, len(pins))}
		for _, pin := range pins {
			p := dtos.Pin{
				UserID:    pin.UserID,
				Emotion:   pin.Emotion,
				Longitude: pin.Location.Longitude,
				Latitude:  pin.Location.Latitude,
				CreatedAt: pin.CreatedAt,
			}
			if pin.Message.Valid {
				p.Message = pin.Message.String
			}
			resp.Pins = append(resp.Pins, p)
		}

		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			log.Println("encode nearby pins response:", err)
		}
	}
}

func GetPinsMeHandler(pinRepo repositories.PinRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		pins, err := pinRepo.QueryUserPins(userID)
		if err != nil {
			log.Println("query user pins:", err)
			http.Error(w, "unable to fetch pins", http.StatusInternalServerError)
			return
		}

		resp := dtos.GetPinListResponse{Pins: make([]dtos.Pin, 0, len(pins))}
		for _, pin := range pins {
			p := dtos.Pin{
				UserID:    pin.UserID,
				Emotion:   pin.Emotion,
				Longitude: pin.Location.Longitude,
				Latitude:  pin.Location.Latitude,
				CreatedAt: pin.CreatedAt,
			}
			if pin.Message.Valid {
				p.Message = pin.Message.String
			}
			resp.Pins = append(resp.Pins, p)
		}

		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(resp); err != nil {
			log.Println("encode user pins response:", err)
		}
	}
}

// POST /pins
func PostPinsHandler(pinRepo repositories.PinRepository) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := r.Context().Value("userID").(uuid.UUID)

		var req dtos.CreatePinRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if err := pinRepo.CreatePin(userID, req.Emotion, req.Message, req.Longitude, req.Latitude, req.Visibility); err != nil {
			http.Error(w, "unable to create pin", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusCreated)
	}
}
