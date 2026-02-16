import { useState, useEffect } from 'react'

const API_URL = '/api/v1'

const STATUS_LABELS = {
  draft: 'Brouillon',
  in_progress: 'En cours',
  delivered: 'Livré',
  archived: 'Archivé',
}

function App() {
  const [projects, setProjects] = useState([])
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ name: '', client: '', description: '', status: 'draft' })

  const fetchProjects = async () => {
    try {
      const res = await fetch(`${API_URL}/projects`)
      const data = await res.json()
      setProjects(data)
    } catch (err) {
      console.error('Failed to fetch projects:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchProjects() }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {
      await fetch(`${API_URL}/projects`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })
      setForm({ name: '', client: '', description: '', status: 'draft' })
      setShowForm(false)
      fetchProjects()
    } catch (err) {
      console.error('Failed to create project:', err)
    }
  }

  const handleDelete = async (id) => {
    if (!confirm('Supprimer ce projet ?')) return
    try {
      await fetch(`${API_URL}/projects/${id}`, { method: 'DELETE' })
      fetchProjects()
    } catch (err) {
      console.error('Failed to delete project:', err)
    }
  }

  const stats = {
    total: projects.length,
    inProgress: projects.filter(p => p.status === 'in_progress').length,
    delivered: projects.filter(p => p.status === 'delivered').length,
  }

  return (
    <div className="container">
      <header>
        <h1>DevBoard</h1>
        <p>Plateforme de gestion de projets ESN</p>
      </header>

      <div className="stats">
        <div className="stat-card">
          <span className="stat-value">{stats.total}</span>
          <span className="stat-label">Projets</span>
        </div>
        <div className="stat-card">
          <span className="stat-value">{stats.inProgress}</span>
          <span className="stat-label">En cours</span>
        </div>
        <div className="stat-card">
          <span className="stat-value">{stats.delivered}</span>
          <span className="stat-label">Livrés</span>
        </div>
      </div>

      <div className="actions">
        <button onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Annuler' : '+ Nouveau projet'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="project-form">
          <input
            placeholder="Nom du projet"
            value={form.name}
            onChange={e => setForm({ ...form, name: e.target.value })}
            required
          />
          <input
            placeholder="Client"
            value={form.client}
            onChange={e => setForm({ ...form, client: e.target.value })}
            required
          />
          <textarea
            placeholder="Description"
            value={form.description}
            onChange={e => setForm({ ...form, description: e.target.value })}
          />
          <select value={form.status} onChange={e => setForm({ ...form, status: e.target.value })}>
            {Object.entries(STATUS_LABELS).map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
          <button type="submit">Créer</button>
        </form>
      )}

      {loading ? (
        <p>Chargement...</p>
      ) : (
        <table className="projects-table">
          <thead>
            <tr>
              <th>Projet</th>
              <th>Client</th>
              <th>Statut</th>
              <th>Créé le</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {projects.map(p => (
              <tr key={p.id}>
                <td>{p.name}</td>
                <td>{p.client}</td>
                <td><span className={`badge badge-${p.status}`}>{STATUS_LABELS[p.status]}</span></td>
                <td>{new Date(p.created_at).toLocaleDateString('fr-FR')}</td>
                <td>
                  <button className="btn-delete" onClick={() => handleDelete(p.id)}>Supprimer</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

export default App
