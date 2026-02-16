# Branch Protection Rules

## Main Branch Protection

Pour configurer la protection de la branche `main` sur GitHub :

### Via Interface GitHub
1. Aller sur : https://github.com/Waddenn/projet-etude/settings/branches
2. Cliquer sur "Add branch protection rule"
3. Branch name pattern : `main`
4. Activer les options suivantes :

#### ✅ Options recommandées :
- ☑ **Require a pull request before merging**
  - ☑ Require approvals: 1
  - ☑ Dismiss stale pull request approvals when new commits are pushed
  
- ☑ **Require status checks to pass before merging**
  - ☑ Require branches to be up to date before merging
  - Sélectionner les checks obligatoires :
    - `lint-backend`
    - `lint-frontend`
    - `lint-terraform`
    - `test-backend`
    - `test-frontend`
    - `trivy-scan-iac`
    
- ☑ **Require conversation resolution before merging**

- ☑ **Do not allow bypassing the above settings**

- ☑ **Restrict who can push to matching branches**
  - Laisser vide = personne ne peut push directement

#### ⚠️ Important :
- Les admins peuvent contourner ces règles en cas d'urgence
- Les tags `v*` peuvent toujours être créés
- Les PRs doivent passer tous les checks avant merge

### Via GitHub CLI (Alternative)
```bash
gh api repos/Waddenn/projet-etude/branches/main/protection \
  --method PUT \
  --field required_status_checks[strict]=true \
  --field required_status_checks[contexts][]=lint-backend \
  --field required_status_checks[contexts][]=lint-frontend \
  --field required_status_checks[contexts][]=lint-terraform \
  --field required_status_checks[contexts][]=test-backend \
  --field required_status_checks[contexts][]=test-frontend \
  --field required_status_checks[contexts][]=trivy-scan-iac \
  --field required_pull_request_reviews[required_approving_review_count]=1 \
  --field required_pull_request_reviews[dismiss_stale_reviews]=true \
  --field enforce_admins=false \
  --field required_conversation_resolution=true \
  --field restrictions=null
```

## Résultat
✅ Impossible de push directement sur `main`  
✅ Obligation de passer par une PR  
✅ Tous les tests doivent passer  
✅ Approbation requise (1 reviewer minimum)
