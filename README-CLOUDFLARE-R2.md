# 🚀 Immich com Cloudflare R2

## Configuração Rápida

### 1. Configurar Cloudflare R2

1. **Criar conta Cloudflare**: https://dash.cloudflare.com/sign-up
2. **Ir para R2**: Dashboard → R2 Object Storage
3. **Criar bucket**: Nome ex: `immich-photos`, região próxima de ti
4. **Obter credenciais**: R2 → Manage Keys → Create API Key

### 2. Configurar Variáveis de Ambiente

1. Copia o ficheiro exemplo:
```bash
cp .env.example .env
```

2. Edita o `.env` com os teus valores da Cloudflare:
```bash
# Substitui pelos teus valores reais
CLOUDFLARE_ACCOUNT_ID=abc123def456
S3_BUCKET_NAME=immich-photos
S3_ACCESS_KEY=your_access_key_here
S3_SECRET_KEY=your_secret_key_here
```

### 3. Iniciar o Immich

```bash
# Criar diretórios necessários
mkdir -p config postgres_data redis_data libraries

# Iniciar os serviços
docker-compose up -d

# Ver logs (opcional)
docker-compose logs -f immich
```

### 4. Acesso

- **WebUI**: http://localhost:8080
- **Setup inicial**: Segue o wizard de configuração

## 🔧 Como funciona

- **Fotos/vídeos**: Armazenados no Cloudflare R2 (S3-compatible)
- **Metadados**: PostgreSQL local
- **Cache**: Redis local
- **Machine Learning**: Modelos locais (~1.5GB)

## 💰 Custos Cloudflare R2

- **Armazenamento**: $0.015/GB/mês
- **Transferências**: Gratuitas entre Cloudflare e internet
- **Operações**: Muito baixas

## 🛠️ Comandos Úteis

```bash
# Parar serviços
docker-compose down

# Ver logs
docker-compose logs immich

# Backup da base de dados
docker-compose exec postgres pg_dump -U postgres immich > backup.sql

# Restaurar backup
docker-compose exec -T postgres psql -U postgres immich < backup.sql
```

## 📁 Estrutura de Ficheiros

```
immich/
├── docker-compose.yml     # Configuração principal
├── .env                   # Variáveis de ambiente (TUA CONFIG)
├── config/               # Modelos ML (~1.5GB)
├── postgres_data/        # Base de dados
├── redis_data/          # Cache
└── libraries/           # Bibliotecas externas (opcional)
```

## ⚠️ Notas Importantes

1. **Backup**: O R2 É para fotos, mas faz backup da base de dados PostgreSQL
2. **Segurança**: Mantém o `.env` privado (está no .gitignore)
3. **Updates**: `docker-compose pull && docker-compose up -d`
4. **Recursos**: Machine Learning pode usar muita RAM/CPU

## 🔄 Migração de Local para R2

Se já tens fotos locais:

1. Configura o R2 como acima
2. No Immich WebUI → Admin → Storage → Migration
3. Seleciona "External Storage" e configura o R2
4. Inicia a migração

## 🚨 Troubleshooting

**Erro de conectividade R2?**
- Verifica Account ID, Access Key, Secret Key
- Confirma que o bucket existe
- Testa a conectividade: `curl https://ACCOUNT_ID.r2.cloudflarestorage.com`

**Erro de permissões?**
- Verifica se a API key tem permissões no bucket
- Confirma região do bucket

**Problemas de performance?**
- Escolhe região R2 mais próxima
- Ajusta `MACHINE_LEARNING_WORKERS` conforme CPU