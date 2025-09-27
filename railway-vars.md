# Environment Variables para Railway

## ⭐ Cloudflare R2 (Obrigatórias)
```
UPLOAD_LOCATION=s3
S3_ENDPOINT=https://2e60eefffc34fef5586904199ea6a451.r2.cloudflarestorage.com
S3_BUCKET_NAME=immich-photos
S3_ACCESS_KEY=7685008c966900904268efa7fe738e57
S3_SECRET_KEY=0815b4ca8277ab6ede2a52840712fca44a71acbbc897978841121b8e7b080a97
S3_REGION=weur
```

## 🤖 Machine Learning (Opcional - para teste)
```
IMMICH_MACHINE_LEARNING_ENABLED=false
```

## 🗄️ Database (Automático no Railway)
- Railway vai configurar automaticamente PostgreSQL
- Redis já está incluído no container via Docker mod

## 🚀 Deploy
1. Adiciona todas as variáveis acima no Railway
2. Redeploy
3. Acede ao URL do Railway
4. Faz setup inicial do Immich
5. Testa upload de foto (deve ir para R2)

## ✅ Como confirmar que R2 está a funcionar:
1. Upload uma foto no Immich
2. Vai ao Cloudflare Dashboard → R2 → immich-photos
3. Deve aparecer a foto lá