variable "name" { type = string }
variable "visibility_timeout_seconds" { type = number, default = 600 }
variable "message_retention_seconds" { type = number, default = 345600 }
variable "max_receive_count" { type = number, default = 3 }
