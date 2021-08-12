# Sample Terraform HCL codes for Azure Monitor Agent (AMA)

## Table of Contents

- [About](#about)
- [Getting Started](#getting_started)

## About <a name = "about"></a>

Azure Monitor Agent(AMA) is now [generally available](https://azure.microsoft.com/ja-jp/updates/azure-monitor-agent-and-data-collection-rules-now-generally-available/), but there isn't much information to use at this time. This repository contains Terraform HCL sample codes for AMA. Please use it as a sample in the transition period.

<img src="https://github.com/ToruMakabe/az-ama-tf-sample/blob/main/images/ama-tf-sample.png?raw=true" width="800">

With this sample, you can mainly experience the following:

* Deploy monitoring services (Azure Monitor Log Analytics workspace, Action Group)
* Deploy sample monitoring target (VM)
* Install AMA extention to VM
* Generate & deploy Data Colletion Rules (VM guest OS performance counters and Syslog)
* Associate Data Collection Rules to VM
* Setup Alert Rules
  * VM host metric (CPU usage)
  * VM guest metric (Disk free space)
  * Syslog query (detection specified strings)

### Note

The sample codes have some workarouds such as managing Data Collection Rules with templates & Azure CLI.

> [Support for Azure Monitor Data Collection Rules](https://github.com/hashicorp/terraform-provider-azurerm/issues/9679)

These restrictions & lacks of Terraform resource may be improved in the future, so please check the latest information on AMA and Terraform before using.

## Getting Started <a name = "getting_started"></a>

1. [Deploy shared monitoring service resources](./terraform/shared/)
2. [Deploy monitoring target resources](./terraform/vm/)

### Prerequisites & Tested

* Terraform: 1.0.4
  * hashicorp/azurerm: 2.71
  * on Linux (need local-exec shell provisioner)
