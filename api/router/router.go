package router

import (
    "encoding/json"
    "net/http"

    "ember/api/auth"
    "ember/api/handlers"
    "ember/api/repositories"

    "github.com/go-chi/chi/v5"
)

func CreateRouter(userRepo repositories.UserRepository) chi.Router {
    r := chi.NewRouter()

    // Simple health/test endpoint
    r.Get("/hello", func(w http.ResponseWriter, _ *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(map[string]string{"message": "Hello, world!"})
    })

    r.Route("/auth", func(r chi.Router) {
        r.Post("/login", handlers.PostLoginHandler(userRepo))
        r.Post("/register", handlers.PostRegisterHandler(userRepo))
    })

	r.Group(func(r chi.Router) {
		r.Use(auth.AuthMiddleware)
		r.Get("/me", handlers.GetMeHandler(userRepo))
		r.Route("/friends", func(r chi.Router) {
			r.Get("/", handlers.GetFriendsHandler(userRepo))
			r.Delete("/{friendID}", handlers.DeleteFriendsHandler(userRepo))
			r.Route("/requests", func(r chi.Router) {
				r.Get("/", handlers.GetFriendRequestsHandler(userRepo))
				r.Post("/{friendID}", handlers.PostFriendRequestsHandler(userRepo))
				r.Patch("/{friendID}", handlers.PatchFriendRequestsHandler(userRepo))
			})
		})
	})

	return r
}
