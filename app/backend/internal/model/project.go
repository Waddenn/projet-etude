package model

import "time"

type ProjectStatus string

const (
	StatusDraft      ProjectStatus = "draft"
	StatusInProgress ProjectStatus = "in_progress"
	StatusDelivered  ProjectStatus = "delivered"
	StatusArchived   ProjectStatus = "archived"
)

type Project struct {
	ID          int           `json:"id"`
	Name        string        `json:"name" binding:"required"`
	Client      string        `json:"client" binding:"required"`
	Status      ProjectStatus `json:"status"`
	Description string        `json:"description"`
	DeliveryAt  *time.Time    `json:"delivery_at,omitempty"`
	CreatedAt   time.Time     `json:"created_at"`
	UpdatedAt   time.Time     `json:"updated_at"`
}
