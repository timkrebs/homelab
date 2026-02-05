variable "ssh_private_key" {
  description = "SSH private key for connecting to nodes"
  type        = string
  sensitive   = true
}

variable "k3s_version" {
  description = "Version of k3s to install"
  type        = string
  default     = "v1.29.0+k3s1"
}

variable "k3s_external_ip" {
  description = "External IP for k3s API server (for remote access)"
  type        = string
  default     = ""
}
