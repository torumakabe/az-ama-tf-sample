terraform {
  required_version = "~> 1.0.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.72"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "ama_sample_shared" {
  name     = local.ama_sample_shared_rg
  location = local.ama_sample_shared_location
}

resource "azurerm_log_analytics_workspace" "ama_sample" {
  name                = "log-ama-sample"
  location            = azurerm_resource_group.ama_sample_shared.location
  resource_group_name = azurerm_resource_group.ama_sample_shared.name
  sku                 = "Free"
  retention_in_days   = 7

  // Workaround: Waiting until the workspace is operational with API
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

// Solution until DCR is supported https://github.com/hashicorp/terraform-provider-azurerm/issues/9679
data "template_file" "data_collection_rule" {
  template = file("./data-collection-rule.json.tpl")

  vars = {
    location                            = local.ama_sample_shared_location
    log_analytics_workspace_resource_id = azurerm_log_analytics_workspace.ama_sample.id
    syslog_facility_names               = jsonencode(var.syslog_facilities_names)
    syslog_levels                       = jsonencode(var.syslog_levels)
  }
}

resource "null_resource" "deploy_data_collection_rule" {
  provisioner "local-exec" {
    command = <<EOT
      az rest --subscription ${data.azurerm_client_config.current.subscription_id} \
              --method PUT \
              --url https://management.azure.com/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.ama_sample_shared.name}/providers/Microsoft.Insights/dataCollectionRules/${local.dcr_name}?api-version=2019-11-01-preview \
              --body '${data.template_file.data_collection_rule.rendered}'
EOT
  }

  triggers = {
    data = md5(data.template_file.data_collection_rule.rendered)
  }
}

resource "azurerm_monitor_action_group" "ama_sample" {
  name                = "ag-ama-sample"
  resource_group_name = azurerm_resource_group.ama_sample_shared.name
  short_name          = "ag-ama-smpl"

  email_receiver {
    name                    = var.email_receiver.name
    email_address           = var.email_receiver.email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "syslog_sample" {
  depends_on = [
    azurerm_log_analytics_workspace.ama_sample
  ]
  name                = "log-alert-syslog-sample"
  resource_group_name = azurerm_resource_group.ama_sample_shared.name
  location            = azurerm_resource_group.ama_sample_shared.location

  action {
    action_group  = [azurerm_monitor_action_group.ama_sample.id]
    email_subject = "[SAMPLE] Syslog alert"
  }

  data_source_id = azurerm_log_analytics_workspace.ama_sample.id
  description    = "Syslog have specified strings - [ERROR_SAMPLE]"
  enabled        = true
  query          = <<-QUERY
  Syslog
  | where SyslogMessage contains "[ERROR_SAMPLE]"
  | summarize AggregatedValue = count() by Computer, bin(TimeGenerated, 5m)
  QUERY
  severity       = 1
  frequency      = 5
  time_window    = 5
  throttling     = 60
  trigger {
    operator  = "GreaterThan"
    threshold = 0
    metric_trigger {
      operator            = "GreaterThan"
      threshold           = 0
      metric_trigger_type = "Total"
      metric_column       = "Computer"
    }
  }
}
