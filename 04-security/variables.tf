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



variable "waf" {
  type = object({
    name  = string
    scope = string
    custom_response_body = object({
      key          = string
      content      = string
      content_type = string
    })
    visibility_config = object({
      cloudwatch_metrics_enabled = bool
      metric_name                = string
      sampled_requests_enabled   = bool
    })
  })

  default = {
    name  = "waf-eks-devopsproject-webacl"
    scope = "REGIONAL"
    custom_response_body = {
      key          = "403-CustomForbiddenResponse"
      content      = "You are not allowed to perform the action you requested."
      content_type = "APPLICATION_JSON"
    }
    visibility_config = {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-eks-devopsproject-webacl-metrics"
      sampled_requests_enabled   = true
    }
  }
}
