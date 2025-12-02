# Associação do WAF Web ACL com o Application Load Balancer
# NOTA: Durante destroy, delete o ingress ANTES de rodar terraform destroy:
# kubectl delete ingress ecommerce-ingress -n ecommerce
# terraform destroy -auto-approve

# DESABILITADO: ALB só existe após criar Ingress no cluster
# Para associar WAF ao ALB, use kubectl annotation após criar o Ingress:
# kubectl annotate ingress <NOME-INGRESS> alb.ingress.kubernetes.io/wafv2-acl-arn=<WAF-ARN>

# resource "aws_wafv2_web_acl_association" "eks_alb" {
#   resource_arn = data.aws_lb.eks_alb[0].arn
#   web_acl_arn  = aws_wafv2_web_acl.this.arn
# }