resource "aws_prometheus_scraper" "this" {
  source {
    eks {
      cluster_arn = local.eks_cluster_arn
      subnet_ids  = data.aws_subnets.eks_private.ids
    }
  }

  destination {
    amp {
      workspace_arn = aws_prometheus_workspace.this.arn
    }
  }

  scrape_configuration = file("${path.module}/prometheus/scrape-config.yml")

  # IMPORTANTE: O scraper cria ENIs que levam ~5min para serem liberadas pela AWS
  # Este lifecycle garante que o Terraform NÃO tente deletar subnets/VPC antes das ENIs serem liberadas
  lifecycle {
    create_before_destroy = false
  }

  # Força dependência: scraper DEVE ser deletado antes de qualquer recurso de rede
  depends_on = [
    aws_prometheus_workspace.this
  ]
}
