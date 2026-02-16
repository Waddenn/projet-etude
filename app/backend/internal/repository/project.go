package repository

import (
	"database/sql"
	"fmt"

	"github.com/votre-groupe/devboard/internal/model"
)

type ProjectRepository struct {
	db *DB
}

func NewProjectRepository(db *DB) *ProjectRepository {
	return &ProjectRepository{db: db}
}

func (r *ProjectRepository) List() ([]model.Project, error) {
	rows, err := r.db.conn.Query(
		`SELECT id, name, client, status, description, delivery_at, created_at, updated_at
		 FROM projects ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var projects []model.Project
	for rows.Next() {
		var p model.Project
		if err := rows.Scan(&p.ID, &p.Name, &p.Client, &p.Status, &p.Description, &p.DeliveryAt, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		projects = append(projects, p)
	}
	return projects, rows.Err()
}

func (r *ProjectRepository) GetByID(id int) (*model.Project, error) {
	var p model.Project
	err := r.db.conn.QueryRow(
		`SELECT id, name, client, status, description, delivery_at, created_at, updated_at
		 FROM projects WHERE id = $1`, id).
		Scan(&p.ID, &p.Name, &p.Client, &p.Status, &p.Description, &p.DeliveryAt, &p.CreatedAt, &p.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *ProjectRepository) Create(p *model.Project) error {
	if p.Status == "" {
		p.Status = model.StatusDraft
	}
	return r.db.conn.QueryRow(
		`INSERT INTO projects (name, client, status, description, delivery_at)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at, updated_at`,
		p.Name, p.Client, p.Status, p.Description, p.DeliveryAt).
		Scan(&p.ID, &p.CreatedAt, &p.UpdatedAt)
}

func (r *ProjectRepository) Update(p *model.Project) error {
	result, err := r.db.conn.Exec(
		`UPDATE projects SET name=$1, client=$2, status=$3, description=$4, delivery_at=$5, updated_at=NOW()
		 WHERE id=$6`,
		p.Name, p.Client, p.Status, p.Description, p.DeliveryAt, p.ID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("project %d not found", p.ID)
	}
	return nil
}

func (r *ProjectRepository) Delete(id int) error {
	result, err := r.db.conn.Exec(`DELETE FROM projects WHERE id = $1`, id)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("project %d not found", id)
	}
	return nil
}
