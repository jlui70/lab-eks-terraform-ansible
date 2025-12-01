# 🚀 Quick Reference - Deploy E-commerce App

## Comandos Essenciais

### 1. Setup Inicial
```bash
# Conectar ao cluster
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1

# Verificar conectividade
kubectl cluster-info
kubectl get nodes
```

### 2. Deploy da Aplicação
```bash
# Aplicar todos os manifestos
kubectl apply -f manifests/

# Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod --all -n ecommerce --timeout=300s

# Verificar status
kubectl get all -n ecommerce
```

### 3. Obter URL de Acesso
```bash
# Ver ingress criado
kubectl get ingress -n ecommerce

# Extrair URL do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Acesse: http://$ALB_URL"
```

### 4. Testes Rápidos
```bash
# Testar conectividade
curl -I http://$ALB_URL

# Ver logs do frontend
kubectl logs -f deployment/ecommerce-ui -n ecommerce

# Testar comunicação interna
kubectl exec -it $(kubectl get pod -l app=ecommerce-ui -n ecommerce -o jsonpath='{.items[0].metadata.name}') -n ecommerce -- curl http://product-catalog:3001
```

### 5. Troubleshooting
```bash
# Ver eventos de problemas
kubectl get events -n ecommerce --sort-by='.lastTimestamp'

# Descrever um pod com problema
kubectl describe pod <pod-name> -n ecommerce

# Reiniciar deployment se necessário
kubectl rollout restart deployment/<deployment-name> -n ecommerce
```

### 6. Limpeza (Se Necessário)
```bash
# Remover aplicação completa
kubectl delete namespace ecommerce

# Confirmar remoção
kubectl get all -n ecommerce
```

## Checklist de Validação

### ✅ Pré-Deploy
- [ ] Cluster EKS ativo
- [ ] AWS LB Controller instalado
- [ ] kubectl configurado
- [ ] Manifestos prontos

### ✅ Pós-Deploy  
- [ ] Todos os 7 pods rodando
- [ ] Services criados (7 services)
- [ ] Ingress com ADDRESS preenchido
- [ ] ALB provisionado na AWS
- [ ] Aplicação acessível via HTTP
- [ ] Login/Signup funcionando
- [ ] Catálogo carregando
- [ ] Console sem erros

### ✅ Funcionalidades
- [ ] Página inicial carrega
- [ ] Formulário de signup funciona
- [ ] Login funciona
- [ ] Produtos aparecem
- [ ] Carrinho funcional
- [ ] Navegação entre páginas

## URLs de Referência

### Aplicação
- **ALB Direto**: http://k8s-ecommerc-ecommerc-[hash].us-east-1.elb.amazonaws.com
- **DNS Personalizado**: http://eks.devopsproject.com.br

### Monitoramento
- **Grafana**: https://g-[workspace-id].grafana-workspace.us-east-1.amazonaws.com
- **Prometheus**: Via AWS Console

## Arquivos Principais

```
manifests/
├── ecommerce-ui.yaml          # Frontend React (porta 4000)
├── product-catalog.yaml       # API produtos (porta 3001) 
├── order-management.yaml      # API pedidos (porta 9090)
├── product-inventory.yaml     # API estoque (porta 3002)
├── profile-management.yaml    # API perfis (porta 3003)
├── shipping-and-handling.yaml # API logística (porta 9091)
├── team-contact-support.yaml  # API suporte (porta 9080)
└── ingress.yaml              # ALB configuration
```

## Variáveis de Ambiente Críticas

### Frontend (ecommerce-ui)
```yaml
env:
- name: REACT_APP_PRODUCT_CATALOG_API_HOST
  value: "http://product-catalog"  # SEM porta!
- name: REACT_APP_ORDER_MANAGEMENT_API_HOST  
  value: "http://order-management"
- name: REACT_APP_PROFILE_MANAGEMENT_API_HOST
  value: "http://profile-management"
```

**⚠️ IMPORTANTE**: Nunca especificar portas nas URLs dos services internos. O Kubernetes resolve automaticamente.