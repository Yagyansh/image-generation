variable "project" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_username" { type = string }
variable "instance_class" { type = string, default = "db.t3.medium" }
variable "allocated_storage" { type = number, default = 20 }
variable "security_group_ids" { type = list(string) }
variable "skip_final_snapshot" { type = bool, default = true }
