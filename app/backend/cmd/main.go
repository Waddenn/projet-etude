package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/votre-groupe/devboard/internal/handler"
	"github.com/votre-groupe/devboard/internal/middleware"
	"github.com/votre-groupe/devboard/internal/repository"
)

func main() {
	dbURL := getEnv("DATABASE_URL", "postgres://devboard:devboard@localhost:5432/devboard?sslmode=disable")

	db, err := repository.NewPostgresDB(dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := db.Migrate(); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	projectRepo := repository.NewProjectRepository(db)
	projectHandler := handler.NewProjectHandler(projectRepo)

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(middleware.PrometheusMiddleware())

	// Health & observability
	r.GET("/health", handler.Health)
	r.GET("/ready", handler.Ready(db))
	r.GET("/metrics", handler.Metrics())

	// API routes
	api := r.Group("/api/v1")
	{
		api.GET("/projects", projectHandler.List)
		api.POST("/projects", projectHandler.Create)
		api.GET("/projects/:id", projectHandler.Get)
		api.PUT("/projects/:id", projectHandler.Update)
		api.DELETE("/projects/:id", projectHandler.Delete)
	}

	port := getEnv("PORT", "8080")
	log.Printf("Starting DevBoard API on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
