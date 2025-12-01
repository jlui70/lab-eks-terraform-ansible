#resource "aws_eks_access_entry" "bash_user" {
#  cluster_name  = aws_eks_cluster.this.name
#  principal_arn = local.bash_user_arn
#  type          = "STANDARD"
#}

#resource "aws_eks_access_entry" "console_user" {
#cluster_name  = aws_eks_cluster.this.name
#principal_arn = local.console_user_arn
#type          = "STANDARD"
#}

#resource "aws_eks_access_policy_association" "bash_user" {
#  cluster_name  = aws_eks_cluster.this.name
#  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#  principal_arn = local.bash_user_arn
#
#  access_scope {
#    type = "cluster"
#  }
#}

#resource "aws_eks_access_policy_association" "console_user" {
#cluster_name  = aws_eks_cluster.this.name
#policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#principal_arn = local.console_user_arn

#access_scope {
#type = "cluster"
#}
#}

# Terraform Role Access
resource "aws_eks_access_entry" "terraform_role" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::620958830769:role/terraform-role"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_role" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::620958830769:role/terraform-role"

  access_scope {
    type = "cluster"
  }
}
