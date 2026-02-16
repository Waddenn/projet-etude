# Policy for DevBoard application
# Allows read access to application secrets only

path "secret/data/devboard/*" {
  capabilities = ["read"]
}

path "secret/metadata/devboard/*" {
  capabilities = ["list"]
}
