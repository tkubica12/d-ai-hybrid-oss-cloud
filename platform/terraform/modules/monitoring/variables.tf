variable "resource_group_name" { 
	type = string 
}
variable "location" { 
	type = string 
}
variable "base_name" { 
	type = string 
}
variable "tags" { 
	type    = map(string)
	default = {}
}
