package repositories

import (
	"database/sql"

	"ember/api/models"

	"github.com/google/uuid"
)

// interface
type PinRepository interface {
	CreatePin(userID uuid.UUID, emotion string, message string, lon float64, lat float64, visibility string) error
	QueryNearbyPins(userID uuid.UUID, lon float64, lat float64, radiusKm float64) ([]models.Pin, error)
	QueryFriendPins(userID uuid.UUID) ([]models.Pin, error)
	QueryUserPins(userID uuid.UUID) ([]models.Pin, error)
}

// implementation
type pinRepository struct {
	db *sql.DB
}

func NewPinRepository(db *sql.DB) PinRepository {
	return &pinRepository{
		db: db,
	}
}

func (p *pinRepository) CreatePin(userID uuid.UUID, emotion string, message string, lon float64, lat float64, visibility string) error {
	const q = `
        INSERT INTO pins (user_id, emotion, message, location, visibility)
        VALUES (
            (SELECT id FROM users WHERE uuid = $1),
            $2,
            $3,
            ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
            $6
        )
    `

	_, err := p.db.Exec(q, userID.String(), emotion, message, lon, lat, visibility)
	return err
}

func (p *pinRepository) QueryNearbyPins(userID uuid.UUID, lon float64, lat float64, radiusKm float64) ([]models.Pin, error) {
	const q = `
		WITH requester AS (
			SELECT id FROM users WHERE uuid = $1
		)
		SELECT
			u.uuid,
			p.emotion,
			p.message,
			ST_X(p.location::geometry) AS longitude,
			ST_Y(p.location::geometry) AS latitude,
			p.visibility,
			p.created_at,
			p.expires_at
		FROM pins p
		JOIN users u ON u.id = p.user_id
		JOIN requester r ON TRUE
		WHERE (
			p.visibility = 'public'
			OR u.uuid = $1
			OR (
				p.visibility = 'friends'
				AND EXISTS (
					SELECT 1
					FROM friendships f
					WHERE f.status = 'accepted'
						AND (
							(f.user_id = r.id AND f.friend_id = p.user_id)
							OR (f.friend_id = r.id AND f.user_id = p.user_id)
						)
				)
			)
		)
		AND (
			$4 <= 0
			OR ST_DWithin(
				p.location,
				ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
				$4 * 1000
			)
		)
		ORDER BY p.created_at DESC
	`

	rows, err := p.db.Query(q, userID.String(), lon, lat, radiusKm)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var pins []models.Pin
	for rows.Next() {
		var pin models.Pin
		if err := rows.Scan(
			&pin.UserID,
			&pin.Emotion,
			&pin.Message,
			&pin.Location.Longitude,
			&pin.Location.Latitude,
			&pin.Visibility,
			&pin.CreatedAt,
			&pin.ExpiresAt,
		); err != nil {
			return nil, err
		}
		pins = append(pins, pin)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return pins, nil
}

func (p *pinRepository) QueryFriendPins(userID uuid.UUID) ([]models.Pin, error) {
	const q = `
		SELECT
			u.uuid,
			p.emotion,
			p.message,
			ST_X(p.location::geometry) AS longitude,
			ST_Y(p.location::geometry) AS latitude,
			p.visibility,
			p.created_at,
			p.expires_at
		FROM pins p
		JOIN users u ON u.id = p.user_id
		WHERE p.visibility IN ('public', 'friends')
		  AND p.user_id IN (
			SELECT friend_id
			FROM friendships
			WHERE status = 'accepted'
			  AND user_id = (SELECT id FROM users WHERE uuid = $1)
		)
		ORDER BY p.created_at DESC
	`

	rows, err := p.db.Query(q, userID.String())
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var pins []models.Pin
	for rows.Next() {
		var pin models.Pin
		if err := rows.Scan(
			&pin.UserID,
			&pin.Emotion,
			&pin.Message,
			&pin.Location.Longitude,
			&pin.Location.Latitude,
			&pin.Visibility,
			&pin.CreatedAt,
			&pin.ExpiresAt,
		); err != nil {
			return nil, err
		}
		pins = append(pins, pin)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return pins, nil
}

func (p *pinRepository) QueryUserPins(userID uuid.UUID) ([]models.Pin, error) {
	const q = `
		SELECT
			u.uuid,
			p.emotion,
			p.message,
			ST_X(p.location::geometry) AS longitude,
			ST_Y(p.location::geometry) AS latitude,
			p.visibility,
			p.created_at,
			p.expires_at
		FROM pins p
		JOIN users u ON u.id = p.user_id
		WHERE u.uuid = $1
		ORDER BY p.created_at DESC
	`

	rows, err := p.db.Query(q, userID.String())
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var pins []models.Pin
	for rows.Next() {
		var pin models.Pin
		if err := rows.Scan(
			&pin.UserID,
			&pin.Emotion,
			&pin.Message,
			&pin.Location.Longitude,
			&pin.Location.Latitude,
			&pin.Visibility,
			&pin.CreatedAt,
			&pin.ExpiresAt,
		); err != nil {
			return nil, err
		}
		pins = append(pins, pin)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return pins, nil
}
