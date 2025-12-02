# Data source para obter informações do ALB criado pelo ALB Controller
# NOTA: Durante destroy, o ALB pode já ter sido deletado via kubectl delete ingress
# Por isso usamos count para tornar este data source opcional
# IMPORTANTE: ALB só existe DEPOIS de criar um Ingress no cluster
data "aws_lb" "eks_alb" {
  count = 0  # Desabilitado - ALB só existe após criar Ingress
  
  tags = {
    "ingress.k8s.aws/resource" = "LoadBalancer"
    "ingress.k8s.aws/stack"    = "ecommerce/ecommerce-ingress"
  }
}