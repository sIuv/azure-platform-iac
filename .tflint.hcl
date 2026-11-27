# Inställningar för tflint, som hittar fel som terraform validate inte ser:
# till exempel VM-storlekar som inte finns i Azure, variabler som aldrig
# används och providers utan versionskrav.
#
# Används av workflowen Terraform Validate för både terraform/bootstrap och
# terraform/infra. Lokalt, från repots rot:
#   tflint --init --config "$PWD/.tflint.hcl"
#   tflint --chdir terraform/infra --config "$PWD/.tflint.hcl"

# Reglerna för Terraform-språket. "recommended" är tflints egna urval av
# regler som nästan alltid pekar på riktiga fel.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Regler för Azure, till exempel att vm_size är en storlek som finns.
# Versionen är låst så att nya regler inte plötsligt får pipelinen att fallera.
# Dependabot uppdaterar inte pluginet, så höj versionen för hand ibland:
# https://github.com/terraform-linters/tflint-ruleset-azurerm/releases
plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
