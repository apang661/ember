package auth


import (
	"fmt"
    "time"
    jwt "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"os"
	"net/http"
	"strings"
	"context"
)

var jwtSecret = []byte(os.Getenv("DB_USER"))

// Auth service for hashing and issuing and authenticating JWTs
func GenerateJWT(userID uuid.UUID) (string, error) {
    claims := jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(1 * time.Hour).Unix(), // token expires in 24h
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(jwtSecret)
}

func ValidateJWT(tokenString string) (uuid.UUID, error) {
    token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
        // Ensure the signing method is HMAC
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return uuid.Nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return jwtSecret, nil
    })
    if err != nil {
        return uuid.Nil, err
    }

    if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
        userIDStr := claims["user_id"].(string)
		userId, err := uuid.Parse(userIDStr)
		if err != nil {
			return uuid.Nil, fmt.Errorf("invalid UUID")
		}
        return userId, nil
    }

    return uuid.Nil, fmt.Errorf("invalid claims")
}

func AuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Get the Authorization header
        authHeader := r.Header.Get("Authorization")
        if authHeader == "" {
            http.Error(w, "missing Authorization header", http.StatusUnauthorized)
            return
        }

        // Expect format: "Bearer <token>"
        parts := strings.SplitN(authHeader, " ", 2)
        if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
            http.Error(w, "invalid Authorization header format", http.StatusUnauthorized)
            return
        }

        token := parts[1] // this is the JWT token

        // You can now validate token
        userID, err := ValidateJWT(token)
        if err != nil {
            http.Error(w, "invalid token", http.StatusUnauthorized)
            return
        }

        // Store userID in context
        ctx := context.WithValue(r.Context(), "userID", userID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

