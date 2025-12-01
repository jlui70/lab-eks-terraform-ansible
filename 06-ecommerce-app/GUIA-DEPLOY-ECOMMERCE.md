# 📚 Guia de Deploy - Aplicação E-commerce Microservices

## 🎯 Objetivo

Este guia demonstra como fazer o deploy de uma aplicação real (e-commerce com microserviços) em um cluster EKS já provisionado. Este exemplo serve como referência para entender os conceitos e etapas necessárias para implantar aplicações complexas em Kubernetes.

## 📋 Pré-requisitos

### ✅ Infraestrutura Necessária
- **Cluster EKS** funcionando (versão 1.32+)
- **AWS Load Balancer Controller** instalado e ativo
- **kubectl** configurado para o cluster
- **Karpenter** para auto-scaling (opcional, mas recomendado)
- **DNS personalizado** configurado (opcional)

### ✅ Verificações Iniciais
```bash
# Verificar conectividade com o cluster
kubectl cluster-info

# Verificar nodes disponíveis
kubectl get nodes

# Verificar AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Verificar se há namespaces em uso
kubectl get namespaces
```

## 🛒 Sobre a Aplicação E-commerce

### Arquitetura da Aplicação
- **Frontend**: React.js (porta 4000)
- **7 Microserviços backend** independentes
- **Comunicação**: APIs REST internas
- **Banco de dados**: Não necessário (dados em memória)
- **Balanceamento**: Kubernetes Services + ALB

### Microserviços Incluídos
1. **ecommerce-ui**: Interface frontend React
2. **product-catalog**: API de catálogo de produtos
3. **order-management**: Gerenciamento de pedidos  
4. **product-inventory**: Controle de estoque
5. **profile-management**: Perfis de usuários
6. **shipping-and-handling**: Logística e entregas
7. **contact-support-team**: Suporte ao cliente

## 🚀 Processo de Deploy - Passo a Passo

### Etapa 1: Preparação do Ambiente

#### 1.1 Criar Estrutura de Projeto
```bash
# Criar diretório para a aplicação
mkdir ecommerce-microservices
cd ecommerce-microservices

# Criar diretório para os manifestos
mkdir manifests
```

#### 1.2 Configurar kubectl para o Cluster
```bash
# Conectar ao cluster EKS
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1

# Verificar contexto ativo
kubectl config current-context
```

### Etapa 2: Obter os Manifestos da Aplicação

#### 2.1 Origem dos Manifestos
Os manifestos originais desta aplicação estão disponíveis em:
- **Repositório**: Projeto Istio Service Mesh (sem Istio)
- **Imagens Docker**: rslim087/* (público no Docker Hub)
- **Formato**: YAMLs padrão Kubernetes

#### 2.2 Manifestos Necessários
```bash
# Lista de arquivos necessários:
manifests/
├── ecommerce-ui.yaml
├── order-management.yaml  
├── product-catalog.yaml
├── product-inventory.yaml
├── profile-management.yaml
├── shipping-and-handling.yaml
├── team-contact-support.yaml
└── ingress.yaml  # ← Criado especificamente para ALB
```

### Etapa 3: Adaptar os Manifestos para EKS

#### 3.1 Correções Necessárias nos Manifestos Originais

**🔧 Problema Identificado**: URLs duplicadas nas variáveis de ambiente  
**🔧 Solução**: Remover portas das URLs de serviços internos

**Antes (com erro):**
```yaml
env:
- name: REACT_APP_PROFILE_API_HOST
  value: "http://profile-management:3003"  # ← Porta duplicada
```

**Depois (correto):**
```yaml
env:
- name: REACT_APP_PROFILE_API_HOST
  value: "http://profile-management"       # ← Apenas nome do serviço
```

**Explicação**: O Kubernetes DNS resolve automaticamente para a porta correta definida no Service. Especificar a porta na URL causa duplicação.

#### 3.2 Criar Ingress para ALB Controller

Criar arquivo `manifests/ingress.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  namespace: ecommerce
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/success-codes: '200,404'
spec:
  rules:
  - host: eks.devopsproject.com.br  # ← DNS personalizado
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ecommerce-ui
            port:
              number: 4000
  - http:  # ← Fallback para ALB direto
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ecommerce-ui
            port:
              number: 4000
```

### Etapa 4: Deploy da Aplicação

#### 4.1 Deploy dos Microserviços
```bash
# Aplicar todos os manifestos
kubectl apply -f manifests/

# Verificar criação dos recursos
kubectl get all -n ecommerce
```

#### 4.2 Aguardar Pods Ficarem Prontos
```bash
# Monitorar status dos pods
kubectl get pods -n ecommerce -w

# Aguardar todos os pods estarem ready
kubectl wait --for=condition=ready pod --all -n ecommerce --timeout=300s
```

#### 4.3 Verificar Services
```bash
# Listar services criados
kubectl get svc -n ecommerce

# Exemplo de saída esperada:
# NAME                    TYPE        CLUSTER-IP     PORT(S)
# ecommerce-ui            ClusterIP   172.20.x.x     4000/TCP
# product-catalog         ClusterIP   172.20.x.x     3001/TCP
# order-management        ClusterIP   172.20.x.x     9090/TCP
# ...
```

### Etapa 5: Configurar Load Balancer

#### 5.1 Verificar Ingress e ALB
```bash
# Verificar status do ingress
kubectl get ingress -n ecommerce

# Aguardar ALB ser provisionado (2-5 minutos)
kubectl describe ingress ecommerce-ingress -n ecommerce
```

#### 5.2 Obter URL do ALB
```bash
# Extrair hostname do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB URL: http://$ALB_URL"
```

### Etapa 6: Testes e Validação

#### 6.1 Teste de Conectividade
```bash
# Testar acesso direto via ALB
curl -I http://$ALB_URL

# Resposta esperada: HTTP/1.1 200 OK
```

#### 6.2 Teste da Aplicação
```bash
# Abrir no navegador
echo "Acesse: http://$ALB_URL"

# Testar funcionalidades:
# 1. Página de login carrega
# 2. Sign up funciona
# 3. Login funciona  
# 4. Catálogo de produtos aparece
# 5. Carrinho funciona
```

### Etapa 7: Configurar DNS Personalizado (Opcional)

#### 7.1 Atualizar Registro DNS
```bash
# No provedor DNS (Hostgator, etc):
# Tipo: CNAME
# Nome: eks (ou subdomínio desejado)  
# Destino: [ALB-HOSTNAME]
# TTL: 300
```

#### 7.2 Aguardar Propagação
```bash
# Verificar propagação DNS
nslookup eks.devopsproject.com.br

# Testar acesso via DNS personalizado
curl -I http://eks.devopsproject.com.br
```

## 🔧 Troubleshooting Comum

### Problema 1: Pods não iniciam
```bash
# Verificar eventos dos pods
kubectl describe pod <pod-name> -n ecommerce

# Verificar logs
kubectl logs <pod-name> -n ecommerce

# Causas comuns:
# - Imagens não encontradas
# - Recursos insuficientes
# - Problemas de rede
```

### Problema 2: ALB não provisiona
```bash
# Verificar AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Verificar eventos do ingress
kubectl describe ingress ecommerce-ingress -n ecommerce

# Verificar IAM roles e políticas
```

### Problema 3: Erros de "Invalid URL"
```bash
# Problema: URLs duplicadas (ex: service:port:port)
# Solução: Remover portas das variáveis de ambiente

# Reiniciar deployment com configuração corrigida
kubectl rollout restart deployment/ecommerce-ui -n ecommerce
```

### Problema 4: Services não se comunicam
```bash
# Testar conectividade interna
kubectl exec -it <frontend-pod> -n ecommerce -- curl http://product-catalog:3001

# Verificar DNS interno do cluster
kubectl exec -it <pod-name> -n ecommerce -- nslookup product-catalog
```

## 📊 Monitoramento e Observabilidade

### Comandos Úteis para Monitoramento
```bash
# Status geral da aplicação
kubectl get all -n ecommerce

# Logs de um microserviço específico
kubectl logs -f deployment/ecommerce-ui -n ecommerce

# Métricas de recursos
kubectl top pods -n ecommerce

# Eventos do namespace
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
```

### Integração com Prometheus/Grafana
- Os pods são automaticamente descobertos pelo Prometheus
- Métricas de CPU/Memória disponíveis no Grafana
- Health checks monitorados continuamente

## 🎯 Conceitos Aprendidos

### 1. **Microserviços em Kubernetes**
- Cada serviço é um Deployment independente
- Services fornecem descoberta de serviços e load balancing
- Comunicação via DNS interno do Kubernetes

### 2. **Ingress e Load Balancing**
- Ingress expõe serviços internos externamente
- ALB Controller provisiona Application Load Balancer na AWS
- Health checks automáticos

### 3. **Configuração de Aplicações**
- Variáveis de ambiente para configuração
- ConfigMaps e Secrets para dados sensíveis
- Comunicação entre microserviços via service names

### 4. **Networking no Kubernetes**
- Cluster DNS resolve service names automaticamente
- Services abstraem os pods individuais
- Ingress fornece roteamento baseado em host/path

## 🎓 Desafio para Estudantes

### Objetivo
Dado um cluster EKS limpo (sem aplicações), fazer o deploy desta aplicação e-commerce completamente funcional.

### Entregáveis Esperados
1. **Aplicação funcionando** via URL pública
2. **Todos os microserviços ativos** (7 serviços)
3. **Funcionalidades testadas**: login, catálogo, carrinho
4. **Documentação** do processo realizado
5. **Screenshots** da aplicação funcionando

### Critérios de Avaliação
- ✅ Aplicação acessível externamente
- ✅ Todos os microserviços respondendo
- ✅ Frontend funcional (sem erros no console)
- ✅ Comunicação entre serviços funcionando
- ✅ Load balancing ativo
- ✅ Processo documentado adequadamente

## 📚 Recursos Adicionais

### Documentação de Referência
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

### Comandos de Limpeza (Caso Necessário)
```bash
# Remover toda a aplicação
kubectl delete namespace ecommerce

# Aguardar recursos serem removidos
kubectl get all -n ecommerce
```

---

## 🎉 Conclusão

Este guia demonstra como fazer o deploy de uma aplicação real com microserviços em Kubernetes, abordando:
- Preparação e adaptação de manifestos
- Configuração de rede e load balancing  
- Troubleshooting de problemas comuns
- Validação e testes da aplicação

**O importante é entender que cada aplicação tem suas particularidades (linguagem, banco de dados, dependências), mas os conceitos fundamentais do Kubernetes permanecem os mesmos.**

---

**Autor**: EKS DevOps Project  
**Data**: Outubro 2025  
**Versão**: 1.0