-- Users
INSERT INTO users (email, password_hash, username, display_name, bio) VALUES
('alice@example.com', 'hashed_pw', 'alice123', 'Alice', 'Hello, I love pins!'),
('bob@example.com', 'hashed_pw', 'bob123', 'Bob', 'I love to travel!'),
('charlie@example.com', 'hashed_pw', 'charlie123', 'Charlie', 'I love to code!');

SELECT *
FROM users
WHERE username = 'alice123';

UPDATE users
SET bio = 'Updated bio here', updated_at = NOW()
WHERE id = 1;

-- Adding a friend
INSERT INTO friendships (user_id, friend_id, status)
VALUES (1, 2, 'pending');

SELECT *
FROM friendships
WHERE user_id = 1;

UPDATE friendships
SET status = 'accepted'
WHERE user_id = 1 AND friend_id = 2;

INSERT INTO friendships (user_id, friend_id, status)
VALUES (2, 1, 'accepted');

-- Blocking a user
INSERT INTO friendships (user_id, friend_id, status)
VALUES (1, 3, 'blocked');

SELECT *
FROM friendships
WHERE user_id = 1;

-- Pins
INSERT INTO pins (user_id, emotion, message, location, visibility)
VALUES (1, 'happy', 'Feeling great in SF!', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography, 'friends');

SELECT *
FROM pins
WHERE user_id = 1;
