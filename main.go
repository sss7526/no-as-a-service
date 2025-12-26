package main

import (
	"encoding/json"
	"encoding/xml"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"

	"github.com/timewasted/go-accept-headers"
)

// Global variable to store rejection reasons
var reasons []string

func main() {
	// Load rejection reasons during startup
	if err := loadRejectionReasons("reasons.json"); err != nil {
		log.Fatalf("Failed to load reasons file: %v", err)
	}

	// Create a new HTTP  server with a custom handler
	mux := http.NewServeMux()
	mux.HandleFunc("/no", rejectionHandler)

	// Add middleware for rate limiting
	handlerWithMiddlewares := rateLimitMiddleware(mux)

	server := &http.Server{
		Addr:         ":3000", // Listen on port 3000
		Handler:      handlerWithMiddlewares,
		ReadTimeout:  5 * time.Second, // Timeout for reading a request
		WriteTimeout: 5 * time.Second, // Timeout for writing a response
		IdleTimeout:  5 * time.Second, // Timeout for idle connections
	}

	log.Printf("No-as-a-Service is running on port %s\n", server.Addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// Load rejection reasons from a JSON file
func loadRejectionReasons(filePath string) error {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}
	if err = json.Unmarshal(data, &reasons); err != nil {
		return err
	}
	return nil
}

// Handler for /no endpoint
func rejectionHandler(w http.ResponseWriter, r *http.Request) {
	// Pick a random rejection reason
	reason := reasons[rand.Intn(len(reasons))] // #nosec G404 -- math/rand is sufficient for this use case (no cryptographic randomness needed)

	// Supported content types
	supportedTypes := []string{
		"application/json",
		"text/plain",
		"text/html",
		"application/xml",
	}

	// Handle the Accept header
	acceptHeader := r.Header.Get("Accept")
	fmt.Println(acceptHeader)

	// Negotiate the best match using go-accept-headers
	bestMatch, err := accept.Negotiate(acceptHeader, supportedTypes...)
	if err != nil {
		// If no suitable match, return 406 Not Acceptable
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotAcceptable)
		if err := json.NewEncoder(w).Encode(map[string]string{"reason": reason}); err != nil {
			log.Println(err)
		}
		return
	}

	switch bestMatch {
	case "application/json":
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(map[string]string{"reason": reason}); err != nil {
			log.Printf("Error encoding json response: %v\n", err)
		}

	case "text/plain", "text/html":
		w.Header().Set("Content-Type", bestMatch)
		_, err := w.Write([]byte(reason))
		if err != nil {
			log.Printf("Error writing %s response: %v\n", bestMatch, err)
		}

	case "application/xml":
		w.Header().Set("Content-Type", "application/xml")
		xmlResponse := struct {
			XMLName xml.Name `xml:"Response"`
			Reason  string   `xml:"Reason"`
		}{
			Reason: reason,
		}
		if err := xml.NewEncoder(w).Encode(xmlResponse); err != nil {
			log.Printf("Error encoding xml response: %v\n", err)
		}

	default:
		// Default to JSON if unsupported Accept type is received
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotAcceptable)
		if err := json.NewEncoder(w).Encode(map[string]string{"reason": reason}); err != nil {
			log.Printf("Error encoding json response: %v\n", err)
		}
	}
}
