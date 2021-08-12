variable "syslog_facilities_names" {
  type = list(string)
  default = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0", "local1", "local2", "local3", "local4",
  "local5", "local6", "local7", "lpr", "mail", "news", "syslog", "user", "UUCP"]
}

variable "syslog_levels" {
  type    = list(string)
  default = ["Error", "Critical", "Alert", "Emergency"]
}

variable "email_receiver" {
  type = object({
    name  = string
    email = string
  })
}
