# E-commerce Microservices Application

## 📋 Visão Geral

Esta stack implementa uma aplicação e-commerce completa com microserviços no cluster EKS existente, **sem necessidade de Istio**. A aplicação utiliza a infraestrutura já provisionada pelas stacks 00-05.

## 🏗️ Arquitetura da Aplicação

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    eks.devopsproject.com.br                                │
│                         (E-commerce App)                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                           ┌────────▼────────┐
                           │  Application    │
                           │  Load Balancer  │ ← Existente (Stack 02)
                           │     (ALB)       │
                           └────────┬────────┘
                                    │
                           ┌────────▼────────┐
                           │   EKS Cluster   │ ← Existente (Stack 02)  
                           │                 │
          ┌────────────────┼─────────────────┼────────────────┐
          │                │                 │                │
    ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐
    │ Frontend  │   │  Product  │   │   Order   │   │ Inventory │
    │    UI     │   │ Catalog   │   │   Mgmt    │   │  Service  │
    └───────────┘   └─────┬─────┘   └─────┬─────┘   └───────────┘
                          │               │
                    ┌─────▼─────┐   ┌─────▼─────┐
                    │  MongoDB  │   │ Profile   │
                    │           │   │ Service   │
                    └───────────┘   └───────────┘
```

## 🛍️ Microserviços Incluídos

1. **ecommerce-ui**: Frontend React da aplicação
2. **product-catalog**: Catálogo de produtos com API REST
3. **order-management**: Gerenciamento de pedidos
4. **product-inventory**: Controle de estoque
5. **profile-management**: Perfis de usuário
6. **shipping-handling**: Logística e entrega  
7. **contact-support**: Suporte ao cliente
8. **mongodb**: Banco de dados para persistência

## 🚀 Deploy da Aplicação

### Pré-requisitos
- ✅ Stacks 00-05 já implementadas
- ✅ Cluster EKS funcionando
- ✅ ALB Controller ativo
- ✅ DNS eks.devopsproject.com.br configurado

### 1. Deploy dos Microserviços
```bash
# Navegar para o diretório da aplicação
cd 06-ecommerce-app

# Criar namespace
kubectl create namespace ecommerce

# Deploy de todos os microserviços
kubectl apply -f manifests/ -n ecommerce

# Verificar status
kubectl get pods -n ecommerce
kubectl get svc -n ecommerce
```

### 2. Verificar Ingress
```bash
# Verificar se o ingress foi criado
kubectl get ingress -n ecommerce

# Aguardar provisioning do ALB (2-3 minutos)
kubectl describe ingress ecommerce-ingress -n ecommerce
```

### 3. Testar Aplicação
```bash
# Testar acesso via DNS personalizado
curl -I http://eks.devopsproject.com.br

# A aplicação e-commerce deve estar acessível
```

## 🌐 URLs de Acesso

- **E-commerce Frontend**: http://eks.devopsproject.com.br
- **API Health Check**: http://eks.devopsproject.com.br/api/health
- **Grafana Monitoring**: https://g-b774166fa1.grafana-workspace.us-east-1.amazonaws.com/

## 📊 Monitoramento

A aplicação será automaticamente monitorada pelo Prometheus/Grafana já configurado:

- **Pod Metrics**: CPU, Memória, Status dos pods
- **Service Metrics**: Latência, throughput das APIs  
- **MongoDB Metrics**: Conexões, queries, performance
- **ALB Metrics**: Requests, response times, errors

## 🔧 Comandos Úteis

### Verificar Status da Aplicação
```bash
# Pods da aplicação
kubectl get pods -n ecommerce

# Services e endpoints
kubectl get svc -n ecommerce
kubectl get endpoints -n ecommerce

# Logs dos microserviços
kubectl logs -f deployment/ecommerce-ui -n ecommerce
kubectl logs -f deployment/product-catalog -n ecommerce
```

### Debug de Conectividade
```bash
# Test interno entre serviços
kubectl exec -it deployment/ecommerce-ui -n ecommerce -- curl http://product-catalog:8080/api/health

# Verificar DNS
kubectl exec -it deployment/ecommerce-ui -n ecommerce -- nslookup product-catalog
```

### Escalar Microserviços
```bash
# Escalar frontend para mais replicas
kubectl scale deployment ecommerce-ui --replicas=3 -n ecommerce

# Auto-scaling será gerenciado pelo Karpenter (Stack 03)
```

## 🎯 Features da Aplicação

### Frontend (React)
- Interface moderna de e-commerce
- Listagem de produtos
- Carrinho de compras
- Checkout simplificado

### Backend APIs
- **RESTful APIs** para todos os serviços
- **Health checks** em `/api/health`
- **Swagger documentation** disponível
- **Error handling** robusto

### Persistência
- **MongoDB** para dados dos produtos
- **Volumes persistentes** configurados
- **Backup automático** (via EBS snapshots)

## 🚨 Troubleshooting

### Aplicação não carrega
```bash
# Verificar status dos pods
kubectl get pods -n ecommerce

# Verificar logs de erro
kubectl describe pod <pod-name> -n ecommerce
kubectl logs <pod-name> -n ecommerce
```

### Erro de conectividade entre serviços
```bash
# Verificar services
kubectl get svc -n ecommerce

# Test de conectividade interna
kubectl exec -it <frontend-pod> -n ecommerce -- curl http://<service-name>:8080/api/health
```

### MongoDB não conecta
```bash
# Verificar status do MongoDB
kubectl get pods -l app=mongodb -n ecommerce

# Verificar logs
kubectl logs -l app=mongodb -n ecommerce

# Verificar persistent volume
kubectl get pv,pvc -n ecommerce
```

## 💰 Custos Adicionais

A aplicação usa a infraestrutura existente, custos adicionais mínimos:
- **Compute**: Pods usam nodes existentes + auto-scaling
- **Storage**: ~$2/mês para volumes MongoDB
- **Network**: Tráfego interno gratuito

**Total estimado adicional**: ~$5/mês

## 🎉 Status

✅ **Aplicação E-commerce**: Implementada  
✅ **7 Microserviços**: Ativos  
✅ **MongoDB**: Persistência configurada  
✅ **ALB Integration**: Funcionando  
✅ **DNS**: eks.devopsproject.com.br  
✅ **Monitoring**: Prometheus/Grafana integrado  

---

**E-commerce microservices aplicação pronta para demonstrações! 🛒🚀**