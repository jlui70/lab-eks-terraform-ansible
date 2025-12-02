variable "region" {
  default = "us-east-1"
}

variable "assume_role" {
  type = object({
    role_arn    = string,
    external_id = string
  })

   default = {
    role_arn    = "arn:aws:iam::620958830769:role/terraform-role"
    external_id = "3b94ec31-9d0d-4b22-9bce-72b6ab95fe1a"
  }
}

variable "tags" {
  type = object({
    Project     = string
    Environment = string
  })

  default = {
    Project     = "eks-devopsproject",
    Environment = "production"
  }
}