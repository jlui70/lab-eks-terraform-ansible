resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "metrics-server"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [
    aws_eks_node_group.this
  ]
}

# Otimização AWS VPC CNI - Reduz consumo de IPs em ~15-20%
# Configura WARM_ENI_TARGET=0, WARM_IP_TARGET=5, MINIMUM_IP_TARGET=10
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"
  
  configuration_values = jsonencode({
    env = {
      WARM_ENI_TARGET    = "0"
      WARM_IP_TARGET     = "5"
      MINIMUM_IP_TARGET  = "10"
    }
  })

  depends_on = [
    aws_eks_node_group.this
  ]
}
