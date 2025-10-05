package auth


import (
	"fmt"
    "time"
    jwt "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"os"
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
