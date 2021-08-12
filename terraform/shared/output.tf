output "la_workspace_resource_id" {
  value = azurerm_log_analytics_workspace.ama_sample.id
}

output "la_workspace_id" {
  value = azurerm_log_analytics_workspace.ama_sample.workspace_id
}

output "dcr_id" {
  value = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.ama_sample_shared.name}/providers/Microsoft.Insights/dataCollectionRules/${local.dcr_name}"
}

output "action_group_id" {
  value = azurerm_monitor_action_group.ama_sample.id
}
