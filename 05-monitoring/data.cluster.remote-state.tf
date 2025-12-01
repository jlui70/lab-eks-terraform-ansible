data "terraform_remote_state" "cluster_stack" {
  backend = "s3"

  config = {
    bucket         = "eks-devopsproject-state-files-<YOUR_ACCOUNT>"
    key            = "cluster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-devopsproject-state-locking"
  }
}
