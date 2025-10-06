-- Users table: identity + profile info
CREATE TABLE users (
    id              BIGSERIAL PRIMARY KEY,                 -- internal DB ID
    uuid            UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(), -- external safe ID
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,                         -- bcrypt
    username        VARCHAR(50) UNIQUE NOT NULL,
    display_name    VARCHAR(100),
    bio             TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Friendships table: stores friend relationships and requests
-- Bidirectional: 2 rows once friendship accepted
CREATE TABLE friendships (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status          VARCHAR(20) NOT NULL CHECK (status IN ('pending','accepted')),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, friend_id)
);

-- Pins table: stores user-generated pins
CREATE TABLE pins (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emotion         VARCHAR(50) NOT NULL,                  -- e.g., happy, sad, excited
    message         TEXT,                                  -- optional message
    location        GEOGRAPHY(Point, 4326) NOT NULL,      -- PostGIS: lat/lng
    visibility      VARCHAR(20) NOT NULL CHECK (visibility IN ('public','friends','private')),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ                               -- optional auto-expire
);
