# Associação do WAF Web ACL com o Application Load Balancer
# NOTA: Durante destroy, delete o ingress ANTES de rodar terraform destroy:
# kubectl delete ingress ecommerce-ingress -n ecommerce
# terraform destroy -auto-approve

resource "aws_wafv2_web_acl_association" "eks_alb" {
  resource_arn = data.aws_lb.eks_alb[0].arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}