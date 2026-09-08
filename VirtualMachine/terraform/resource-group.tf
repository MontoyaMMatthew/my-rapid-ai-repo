resource "azurerm_resource_group" "studentRG" {
  name     = var.studentRGName
  location = var.studentLocation
}