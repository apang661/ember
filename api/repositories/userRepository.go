package repositories

import (
	"ember/api/models"

	"database/sql"
	"github.com/google/uuid"
)

// interface
type UserRepository interface {
	CreateUser(username string, email string, passwordHash string) (uuid.UUID, error)
	GetUserByUUID(id uuid.UUID) (*models.User, error)
	GetPasswordHashByEmail(email string) (uuid.UUID, string, error)
	GetFriendsByUUID(id uuid.UUID) ([]models.User, error)
	CreateFriendRequest(userID uuid.UUID, friendID uuid.UUID) (bool, error)
	AcceptFriendRequest(userID uuid.UUID, requesterID uuid.UUID) (bool, error)
	RejectFriendRequest(userID uuid.UUID, requesterID uuid.UUID) (bool, error)
	DeleteFriend(userID uuid.UUID, friendID uuid.UUID) (bool, error)
}

// implementation
type userRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) UserRepository {
	return &userRepository{
		db: db,
	}
}

func (ur *userRepository) CreateUser(username string, email string, passwordHash string) (uuid.UUID, error) {
	var id uuid.UUID
	err := ur.db.QueryRow(
		"INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING uuid",
		username, email, passwordHash,
	).Scan(&id)
	return id, err
}

func (ur *userRepository) GetUserByUUID(id uuid.UUID) (*models.User, error) {
	var user models.User

	err := ur.db.QueryRow(
		`SELECT uuid, username, display_name, bio, created_at, updated_at 
		 FROM users WHERE uuid = $1`,
		id,
	).Scan(
		&user.ID,
		&user.Username,
		&user.DisplayName,
		&user.Bio,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // user not found
		}
		return nil, err
	}

	return &user, nil
}

func (ur *userRepository) GetFriendsByUUID(id uuid.UUID) ([]models.User, error) {
	var users []models.User

	rows, err := ur.db.Query(
		`SELECT uuid, username, display_name, bio, created_at, updated_at 
		 FROM users WHERE id IN
			(SELECT friend_id
			FROM friendships WHERE status = 'accepted' AND user_id = 
				(SELECT id FROM USERS WHERE uuid = $1))`,
		id,
	)
	if err != nil {
		return users, err
	}
	defer rows.Close()

	for rows.Next() {
		var user models.User
		rows.Scan(
			&user.ID,
			&user.Username,
			&user.DisplayName,
			&user.Bio,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		users = append(users, user)
	}

	if err = rows.Err(); err != nil {
		return users, err
	}

	return users, nil
}

// GetPasswordHashByEmail fetches the user's UUID and password_hash by email
func (ur *userRepository) GetPasswordHashByEmail(email string) (uuid.UUID, string, error) {
	var id uuid.UUID
	var passwordHash string

	query := `SELECT uuid, password_hash FROM users WHERE email = $1`
	err := ur.db.QueryRow(query, email).Scan(&id, &passwordHash)
	if err != nil {
		return uuid.Nil, "", err
	}

	return id, passwordHash, nil
}

func (ur *userRepository) CreateFriendRequest(userID uuid.UUID, friendID uuid.UUID) (bool, error) {
	query := `
		INSERT INTO friendships (user_id, friend_id, status)
		SELECT 
			(SELECT id FROM users WHERE uuid = $1),
			(SELECT id FROM users WHERE uuid = $2),
			'pending'
		WHERE NOT EXISTS (
			SELECT 1 FROM friendships
			WHERE user_id = (SELECT id FROM users WHERE uuid = $1)
				AND friend_id = (SELECT id FROM users WHERE uuid = $2)
			AND status IN ('pending', 'accepted')
		);
	`

	result, err := ur.db.Exec(query, userID.String(), friendID.String())
	if err != nil {
		return false, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return false, err
	}

	// If no row was inserted, that means a friendship already exists or is pending.
	return rowsAffected > 0, nil
}

func (ur *userRepository) AcceptFriendRequest(userID, requesterID uuid.UUID) (bool, error) {
	tx, err := ur.db.Begin()
	if err != nil {
		return false, err
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		} else {
			tx.Commit()
		}
	}()

	// Update incoming pending request → accepted (requester → user)
	updateQuery := `
		UPDATE friendships
		SET status = 'accepted', created_at = now()
		WHERE user_id = (SELECT id FROM users WHERE uuid = $1)
		  AND friend_id = (SELECT id FROM users WHERE uuid = $2)
		  AND status = 'pending';
	`
	result, err := tx.Exec(updateQuery, requesterID.String(), userID.String())
	if err != nil {
		return false, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return false, err
	}
	if rowsAffected == 0 {
		return false, nil // no pending request to accept
	}


	// Delete any reverse pending request (user → requester)
	deleteQuery := `
		DELETE FROM friendships
		WHERE user_id = (SELECT id FROM users WHERE uuid = $1)
		  AND friend_id = (SELECT id FROM users WHERE uuid = $2)
		  AND status = 'pending';
	`
	_, err = tx.Exec(deleteQuery, userID.String(), requesterID.String())
	if err != nil {
		return false, err
	}

	// Insert reverse accepted row (user → requester)
	insertQuery := `
		INSERT INTO friendships (user_id, friend_id, status)
		VALUES ((SELECT id FROM users WHERE uuid = $1),
		        (SELECT id FROM users WHERE uuid = $2),
		        'accepted');
	`
	_, err = tx.Exec(insertQuery, userID.String(), requesterID.String())
	if err != nil {
		return false, err
	}

	return true, nil
}

func (ur *userRepository) RejectFriendRequest(userID uuid.UUID, requesterID uuid.UUID) (bool, error) {
	// Deletes the pending request from requester → user
	query := `
		DELETE FROM friendships
		WHERE user_id = (SELECT id FROM users WHERE uuid = $1)
		  AND friend_id = (SELECT id FROM users WHERE uuid = $2)
		  AND status = 'pending';
	`

	result, err := ur.db.Exec(query, requesterID.String(), userID.String())
	if err != nil {
		return false, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return false, err
	}

	return rowsAffected > 0, nil
}

// bidirectional delete
func (ur *userRepository) DeleteFriend(userID uuid.UUID, friendID uuid.UUID) (bool, error) {
	query := `DELETE FROM friendships
			  WHERE user_id = (SELECT id FROM users WHERE uuid = $1)
			  AND friend_id = (SELECT id FROM users WHERE uuid = $2);`

	result, err := ur.db.Exec(query, userID.String(), friendID.String())
	if err != nil {
		return false, err
	}

	rowsAffectedOne, err := result.RowsAffected()
	if err != nil {
		return false, err
	}

	query = `DELETE FROM friendships
			  WHERE user_id = (SELECT id FROM users WHERE uuid = $1)
			  AND friend_id = (SELECT id FROM users WHERE uuid = $2);`

	result, err = ur.db.Exec(query, friendID.String(), userID.String())
	if err != nil {
		return false, err
	}

	rowsAffectedTwo, err := result.RowsAffected()
	if err != nil {
		return false, err
	}

	if rowsAffectedOne + rowsAffectedTwo == 0 {
		return false, nil
	}

	return true, nil
}


