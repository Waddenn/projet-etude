#!/bin/bash
# Seed the database with sample project data
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080/api/v1}"

echo "Seeding database with sample projects..."

projects=(
  '{"name":"Portail Citoyen","client":"Mairie de Lyon","status":"in_progress","description":"Portail web pour les démarches administratives"}'
  '{"name":"E-commerce PME","client":"Boulangerie Martin","status":"delivered","description":"Boutique en ligne avec paiement intégré"}'
  '{"name":"App Mobile Santé","client":"Clinique du Parc","status":"draft","description":"Application de prise de rendez-vous"}'
  '{"name":"Dashboard RH","client":"Groupe Nexia","status":"in_progress","description":"Tableau de bord RH avec indicateurs temps réel"}'
  '{"name":"API Facturation","client":"Cabinet Durand","status":"delivered","description":"API REST de gestion de factures"}'
  '{"name":"Refonte Intranet","client":"Région Occitanie","status":"draft","description":"Modernisation de l intranet régional"}'
)

for project in "${projects[@]}"; do
  curl -s -X POST "$API_URL/projects" \
    -H "Content-Type: application/json" \
    -d "$project" > /dev/null
  echo "  Created: $(echo "$project" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)"
done

echo "Done! $(echo ${#projects[@]}) projects created."
