package handlers

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"ember/api/dtos"
	"ember/api/models"
	"ember/api/repositories"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type mockUserRepo struct {
	createUserFn             func(username string, email string, passwordHash string) (uuid.UUID, error)
	getUserByUUIDFn          func(id uuid.UUID) (*models.User, error)
	getPasswordHashByEmailFn func(email string) (uuid.UUID, string, error)
	getFriendsByUUIDFn       func(id uuid.UUID) ([]models.User, error)
	getFriendRequestsFn      func(id uuid.UUID) ([]models.User, []models.User, error)
	createFriendRequestFn    func(userID uuid.UUID, friendID uuid.UUID) (bool, error)
	acceptFriendRequestFn    func(userID uuid.UUID, requesterID uuid.UUID) (bool, error)
	rejectFriendRequestFn    func(userID uuid.UUID, requesterID uuid.UUID) (bool, error)
	deleteFriendFn           func(userID uuid.UUID, friendID uuid.UUID) (bool, error)
}

func (m *mockUserRepo) CreateUser(username string, email string, passwordHash string) (uuid.UUID, error) {
	if m.createUserFn != nil {
		return m.createUserFn(username, email, passwordHash)
	}
	return uuid.Nil, nil
}

func (m *mockUserRepo) GetUserByUUID(id uuid.UUID) (*models.User, error) {
	if m.getUserByUUIDFn != nil {
		return m.getUserByUUIDFn(id)
	}
	return nil, nil
}

func (m *mockUserRepo) GetPasswordHashByEmail(email string) (uuid.UUID, string, error) {
	if m.getPasswordHashByEmailFn != nil {
		return m.getPasswordHashByEmailFn(email)
	}
	return uuid.Nil, "", nil
}

func (m *mockUserRepo) GetFriendsByUUID(id uuid.UUID) ([]models.User, error) {
	if m.getFriendsByUUIDFn != nil {
		return m.getFriendsByUUIDFn(id)
	}
	return nil, nil
}

func (m *mockUserRepo) GetFriendRequestsByUUID(id uuid.UUID) ([]models.User, []models.User, error) {
	if m.getFriendRequestsFn != nil {
		return m.getFriendRequestsFn(id)
	}
	return nil, nil, nil
}

func (m *mockUserRepo) CreateFriendRequest(userID uuid.UUID, friendID uuid.UUID) (bool, error) {
	if m.createFriendRequestFn != nil {
		return m.createFriendRequestFn(userID, friendID)
	}
	return false, nil
}

func (m *mockUserRepo) AcceptFriendRequest(userID uuid.UUID, requesterID uuid.UUID) (bool, error) {
	if m.acceptFriendRequestFn != nil {
		return m.acceptFriendRequestFn(userID, requesterID)
	}
	return false, nil
}

func (m *mockUserRepo) RejectFriendRequest(userID uuid.UUID, requesterID uuid.UUID) (bool, error) {
	if m.rejectFriendRequestFn != nil {
		return m.rejectFriendRequestFn(userID, requesterID)
	}
	return false, nil
}

func (m *mockUserRepo) DeleteFriend(userID uuid.UUID, friendID uuid.UUID) (bool, error) {
	if m.deleteFriendFn != nil {
		return m.deleteFriendFn(userID, friendID)
	}
	return false, nil
}

func TestPostRegisterHandler_Success(t *testing.T) {
	t.Helper()
	var capturedHash string
	expectedID := uuid.New()

	repo := &mockUserRepo{
		createUserFn: func(username string, email string, passwordHash string) (uuid.UUID, error) {
			if username != "alice" || email != "alice@example.com" {
				t.Fatalf("unexpected credentials passed to CreateUser: %s %s", username, email)
			}
			capturedHash = passwordHash
			return expectedID, nil
		},
	}

	handler := PostRegisterHandler(repo)
	req := httptest.NewRequest(http.MethodPost, "/auth/register", strings.NewReader(`{"username":"alice","email":"alice@example.com","password":"supersecret"}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected status %d got %d", http.StatusCreated, rec.Code)
	}

	if capturedHash == "" || capturedHash == "supersecret" {
		t.Fatalf("expected hashed password, got %q", capturedHash)
	}

	var resp dtos.RegisterResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.UserID != expectedID {
		t.Fatalf("expected user ID %s got %s", expectedID, resp.UserID)
	}
}

func TestPostRegisterHandler_InvalidJSON(t *testing.T) {
	repo := &mockUserRepo{}
	handler := PostRegisterHandler(repo)

	req := httptest.NewRequest(http.MethodPost, "/auth/register", strings.NewReader(`invalid json`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPostLoginHandler_Success(t *testing.T) {
	userID := uuid.New()
	hash, err := bcrypt.GenerateFromPassword([]byte("supersecret"), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("unable to hash password: %v", err)
	}

	repo := &mockUserRepo{
		getPasswordHashByEmailFn: func(email string) (uuid.UUID, string, error) {
			if email != "alice@example.com" {
				t.Fatalf("unexpected email %s", email)
			}
			return userID, string(hash), nil
		},
	}

	os.Setenv("DB_USER", "testsecret")

	handler := PostLoginHandler(repo)
	req := httptest.NewRequest(http.MethodPost, "/auth/login", strings.NewReader(`{"email":"alice@example.com","password":"supersecret"}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}

	var resp dtos.LoginResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.Token == "" {
		t.Fatalf("expected JWT token in response")
	}
}

func TestPostLoginHandler_InvalidCredentials(t *testing.T) {
	hash, err := bcrypt.GenerateFromPassword([]byte("supersecret"), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("unable to hash password: %v", err)
	}

	repo := &mockUserRepo{
		getPasswordHashByEmailFn: func(email string) (uuid.UUID, string, error) {
			return uuid.New(), string(hash), nil
		},
	}

	handler := PostLoginHandler(repo)
	req := httptest.NewRequest(http.MethodPost, "/auth/login", strings.NewReader(`{"email":"alice@example.com","password":"wrong"}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status %d got %d", http.StatusUnauthorized, rec.Code)
	}
}

func TestPostLoginHandler_UserNotFound(t *testing.T) {
	repo := &mockUserRepo{
		getPasswordHashByEmailFn: func(email string) (uuid.UUID, string, error) {
			return uuid.Nil, "", sql.ErrNoRows
		},
	}

	handler := PostLoginHandler(repo)
	req := httptest.NewRequest(http.MethodPost, "/auth/login", strings.NewReader(`{"email":"alice@example.com","password":"supersecret"}`))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status %d got %d", http.StatusUnauthorized, rec.Code)
	}
}

func TestGetMeHandler_Success(t *testing.T) {
	userID := uuid.New()
	now := time.Now().UTC()
	repo := &mockUserRepo{
		getUserByUUIDFn: func(id uuid.UUID) (*models.User, error) {
			if id != userID {
				t.Fatalf("unexpected user ID %s", id)
			}
			return &models.User{
				ID:          userID,
				Username:    "alice",
				DisplayName: sql.NullString{String: "Alice", Valid: true},
				Bio:         sql.NullString{String: "Adventurer", Valid: true},
				CreatedAt:   now,
				UpdatedAt:   now,
			}, nil
		},
	}

	handler := GetMeHandler(repo)
	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}

	var resp dtos.GetMeResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode GetMe response: %v", err)
	}

	if resp.ID != userID || resp.Username != "alice" || resp.DisplayName != "Alice" || resp.Bio != "Adventurer" {
		t.Fatalf("unexpected response payload: %+v", resp)
	}
}

func TestGetMeHandler_Error(t *testing.T) {
	repo := &mockUserRepo{
		getUserByUUIDFn: func(id uuid.UUID) (*models.User, error) {
			return nil, errors.New("boom")
		},
	}

	handler := GetMeHandler(repo)
	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected status %d got %d", http.StatusInternalServerError, rec.Code)
	}
}

func TestGetFriendsHandler_Success(t *testing.T) {
	userID := uuid.New()
	friendID := uuid.New()

	repo := &mockUserRepo{
		getFriendsByUUIDFn: func(id uuid.UUID) ([]models.User, error) {
			if id != userID {
				t.Fatalf("unexpected user ID %s", id)
			}
			return []models.User{
				{
					ID:          friendID,
					Username:    "bob",
					DisplayName: sql.NullString{String: "Bob", Valid: true},
					Bio:         sql.NullString{String: "Explorer", Valid: true},
				},
			}, nil
		},
	}

	handler := GetFriendsHandler(repo)
	req := httptest.NewRequest(http.MethodGet, "/friends", nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}

	var resp dtos.GetFriendsResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode friends response: %v", err)
	}

	if len(resp.Friends) != 1 || resp.Friends[0].ID != friendID || resp.Friends[0].DisplayName != "Bob" {
		t.Fatalf("unexpected friends payload: %+v", resp.Friends)
	}
}

func TestDeleteFriendsHandler_Success(t *testing.T) {
	userID := uuid.New()
	friendID := uuid.New()

	repo := &mockUserRepo{
		deleteFriendFn: func(u uuid.UUID, f uuid.UUID) (bool, error) {
			if u != userID || f != friendID {
				t.Fatalf("unexpected IDs %s %s", u, f)
			}
			return true, nil
		},
	}

	handler := DeleteFriendsHandler(repo)
	req := httptest.NewRequest(http.MethodDelete, "/friends/"+friendID.String(), nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	req = addFriendIDParam(req, friendID.String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}
}

func TestDeleteFriendsHandler_NotFound(t *testing.T) {
	repo := &mockUserRepo{
		deleteFriendFn: func(u uuid.UUID, f uuid.UUID) (bool, error) {
			return false, nil
		},
	}

	handler := DeleteFriendsHandler(repo)
	req := httptest.NewRequest(http.MethodDelete, "/friends/"+uuid.New().String(), nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, uuid.New().String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPostFriendRequestsHandler_Success(t *testing.T) {
	userID := uuid.New()
	targetID := uuid.New()

	repo := &mockUserRepo{
		createFriendRequestFn: func(u uuid.UUID, f uuid.UUID) (bool, error) {
			if u != userID || f != targetID {
				t.Fatalf("unexpected IDs %s %s", u, f)
			}
			return true, nil
		},
	}

	handler := PostFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPost, "/friends/requests/"+targetID.String(), nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	req = addFriendIDParam(req, targetID.String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}
}

func TestPostFriendRequestsHandler_TargetMissing(t *testing.T) {
	repo := &mockUserRepo{
		createFriendRequestFn: func(u uuid.UUID, f uuid.UUID) (bool, error) {
			return false, repositories.ErrTargetUserNotFound
		},
	}

	handler := PostFriendRequestsHandler(repo)
	target := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/friends/requests/"+target.String(), nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, target.String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPostFriendRequestsHandler_Duplicate(t *testing.T) {
	repo := &mockUserRepo{
		createFriendRequestFn: func(u uuid.UUID, f uuid.UUID) (bool, error) {
			return false, nil
		},
	}

	handler := PostFriendRequestsHandler(repo)
	target := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/friends/requests/"+target.String(), nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, target.String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPostFriendRequestsHandler_SelfRequest(t *testing.T) {
	userID := uuid.New()
	repo := &mockUserRepo{}

	handler := PostFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPost, "/friends/requests/"+userID.String(), nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	req = addFriendIDParam(req, userID.String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPostFriendRequestsHandler_InvalidUUID(t *testing.T) {
	repo := &mockUserRepo{}
	handler := PostFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPost, "/friends/requests/not-a-uuid", nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, "not-a-uuid")
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestGetFriendRequestsHandler_Success(t *testing.T) {
	userID := uuid.New()
	incomingID := uuid.New()
	outgoingID := uuid.New()

	repo := &mockUserRepo{
		getFriendRequestsFn: func(id uuid.UUID) ([]models.User, []models.User, error) {
			if id != userID {
				t.Fatalf("unexpected user ID %s", id)
			}
			return []models.User{
					{ID: incomingID, Username: "bob", DisplayName: sql.NullString{String: "Bob", Valid: true}},
				},
				[]models.User{
					{ID: outgoingID, Username: "carol", DisplayName: sql.NullString{String: "Carol", Valid: true}},
				},
				nil
		},
	}

	handler := GetFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodGet, "/friends/requests", nil)
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}

	var resp dtos.GetFriendRequestsResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode friend requests response: %v", err)
	}

	if len(resp.Incoming) != 1 || resp.Incoming[0].ID != incomingID {
		t.Fatalf("unexpected incoming requests payload: %+v", resp.Incoming)
	}

	if len(resp.Outgoing) != 1 || resp.Outgoing[0].ID != outgoingID {
		t.Fatalf("unexpected outgoing requests payload: %+v", resp.Outgoing)
	}
}

func TestPatchFriendRequestsHandler_Accept(t *testing.T) {
	userID := uuid.New()
	requesterID := uuid.New()

	repo := &mockUserRepo{
		acceptFriendRequestFn: func(u uuid.UUID, r uuid.UUID) (bool, error) {
			if u != userID || r != requesterID {
				t.Fatalf("unexpected IDs %s %s", u, r)
			}
			return true, nil
		},
	}

	handler := PatchFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPatch, "/friends/requests/"+requesterID.String(), strings.NewReader(`{"status":"accepted"}`))
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	req = addFriendIDParam(req, requesterID.String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}
}

func TestPatchFriendRequestsHandler_AcceptNoPending(t *testing.T) {
	repo := &mockUserRepo{
		acceptFriendRequestFn: func(u uuid.UUID, r uuid.UUID) (bool, error) {
			return false, nil
		},
	}

	handler := PatchFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPatch, "/friends/requests/"+uuid.New().String(), strings.NewReader(`{"status":"accepted"}`))
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, uuid.New().String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPatchFriendRequestsHandler_Reject(t *testing.T) {
	userID := uuid.New()
	requesterID := uuid.New()

	repo := &mockUserRepo{
		rejectFriendRequestFn: func(u uuid.UUID, r uuid.UUID) (bool, error) {
			if u != userID || r != requesterID {
				t.Fatalf("unexpected IDs %s %s", u, r)
			}
			return true, nil
		},
	}

	handler := PatchFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPatch, "/friends/requests/"+requesterID.String(), strings.NewReader(`{"status":"rejected"}`))
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(context.WithValue(req.Context(), "userID", userID))
	req = addFriendIDParam(req, requesterID.String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d got %d", http.StatusOK, rec.Code)
	}
}

func TestPatchFriendRequestsHandler_RejectNoPending(t *testing.T) {
	repo := &mockUserRepo{
		rejectFriendRequestFn: func(u uuid.UUID, r uuid.UUID) (bool, error) {
			return false, nil
		},
	}

	handler := PatchFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPatch, "/friends/requests/"+uuid.New().String(), strings.NewReader(`{"status":"rejected"}`))
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, uuid.New().String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPatchFriendRequestsHandler_InvalidStatus(t *testing.T) {
	repo := &mockUserRepo{}

	handler := PatchFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPatch, "/friends/requests/"+uuid.New().String(), strings.NewReader(`{"status":"unknown"}`))
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, uuid.New().String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestPatchFriendRequestsHandler_InvalidBody(t *testing.T) {
	repo := &mockUserRepo{}

	handler := PatchFriendRequestsHandler(repo)
	req := httptest.NewRequest(http.MethodPatch, "/friends/requests/"+uuid.New().String(), strings.NewReader(`invalid`))
	req = req.WithContext(context.WithValue(req.Context(), "userID", uuid.New()))
	req = addFriendIDParam(req, uuid.New().String())
	rec := httptest.NewRecorder()

	handler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d got %d", http.StatusBadRequest, rec.Code)
	}
}

func addFriendIDParam(req *http.Request, friendID string) *http.Request {
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("friendID", friendID)
	ctx := context.WithValue(req.Context(), chi.RouteCtxKey, rctx)
	return req.WithContext(ctx)
}
