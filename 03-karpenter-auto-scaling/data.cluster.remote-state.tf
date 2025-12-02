data "terraform_remote_state" "cluster_stack" {
  backend = "s3"

  config = {
    bucket         = "eks-devopsproject-state-files-620958830769"
    key            = "cluster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-devopsproject-state-locking"
  }
}
