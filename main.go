package main

import (
    "encoding/json"
    "encoding/xml"
    "fmt"
    "os"
    "log"
    "math/rand"
    "net/http"
    "strings"
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
        Addr: ":3000", // Listen on port 3000
        Handler: handlerWithMiddlewares,
        ReadTimeout: 5 * time.Second, // Timeout for reading a request
        WriteTimeout: 5 * time.Second, // Timeout for writing a response
        IdleTimeout: 5 * time.Second, // Timeout for idle connections
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
func rejectionHandler(w http.ResponseWriter, r * http.Request) {
    // Pick a random rejection reason
    reason := reasons[rand.Intn(len(reasons))]

    // Handle the Accept header
    acceptHeader := r.Header.Get("Accept")
    fmt.Println(acceptHeader)
    switch {
    case strings.Contains(acceptHeader, "application/json") || acceptHeader == "":
        w.Header().Set("Content-Type", "application/json")
        _ = json.NewEncoder(w).Encode(map[string]string{"reason": reason})
    
    case strings.Contains(acceptHeader, "text/plain") || strings.Contains(acceptHeader, "text/html"):
        w.Header().Set("Content-Type", "text/plain")
        w.Write([]byte(reason))

    case strings.Contains(acceptHeader, "application/xml"):
        w.Header().Set("Content-Type", "application/xml")
        xmlResponse := struct {
            XMLName xml.Name `xml:"Response"`
            Reason string `xml:"Reason"`
        }{
            Reason: reason,
        }
        xml.NewEncoder(w).Encode(xmlResponse)
    
    default:
        // Default to JSON if unsupported Accept type is received
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusNotAcceptable)
        json.NewEncoder(w).Encode(map[string]string{"reason": reason})
    }
}
