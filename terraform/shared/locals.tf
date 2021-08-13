locals {
  ama_sample_shared_rg       = "rg-ama-sample-shared"
  ama_sample_shared_location = "japaneast"
  dcr_name                   = "dcr-ama-sample"
  data_collection_rule = templatefile("./data-collection-rule.json.tpl",
    {
      location                            = local.ama_sample_shared_location
      log_analytics_workspace_resource_id = azurerm_log_analytics_workspace.ama_sample.id
      syslog_facility_names               = jsonencode(var.syslog_facilities_names)
      syslog_levels                       = jsonencode(var.syslog_levels)
    }
  )
}
