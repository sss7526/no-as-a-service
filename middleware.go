package main

import (
	"net/http"
	"sync"
	"time"
	"fmt"
)

// Rate limiter definition
type RateLimiter struct {
	visitors map[string]time.Time
	mu sync.Mutex
}

func NewRateLimiter() *RateLimiter {
	return &RateLimiter{
		visitors: make(map[string]time.Time),
	}
}

func (rl *RateLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	cleanupDuration := 1 * time.Minute
	now := time.Now()

	// Cleanup old entries
	for visitor, lastSeen := range rl.visitors {
		if now.Sub(lastSeen) > cleanupDuration {
			delete(rl.visitors, visitor)
		}
	}

	// Check if the IP is already preset
	lastSeen, exists := rl.visitors[ip]
	if exists && now.Sub(lastSeen) < time.Second {
		return false // Limit to 1 request per second
	}

	// Add or update the visitor IP
	rl.visitors[ip] = now
	return true
}

func rateLimitMiddleware(next http.Handler) http.Handler {
	rl := NewRateLimiter()

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := r.RemoteAddr // Can also handle proxies here
		fmt.Println(ip)
		if !rl.Allow(ip) {
			http.Error(w, "Too many requests", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}