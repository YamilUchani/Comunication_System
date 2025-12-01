# Guía Rápida: Habilitar APIs de Google Cloud

## 🚨 Error Actual
```
missing required API artifactregistry.googleapis.com
```

## ✅ Solución: Habilitar APIs Necesarias

Se abrió automáticamente la página para habilitar Artifact Registry API.

### Paso 1: Artifact Registry API

1. En la página que se abrió, haz clic en **"ENABLE" / "HABILITAR"**
2. Espera ~30 segundos a que se habilite
3. Verás un mensaje: "API enabled successfully"

### Paso 2: Cloud Build API (también necesaria)

1. Ve a: https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com?project=stemforall-f57ac
2. Haz clic en **"ENABLE" / "HABILITAR"**
3. Espera ~30 segundos

### Paso 3: Cloud Functions API (probablemente ya está)

1. Ve a: https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com?project=stemforall-f57ac
2. Si dice "MANAGE", ya está habilitada ✅
3. Si dice "ENABLE", habilítala

### Paso 4: Reintentar el Despliegue

Después de habilitar las APIs, ejecuta:

```powershell
firebase deploy --only functions
```

## ⏱️ Tiempo Estimado

- Habilitar cada API: ~30 segundos
- Primer despliegue de Functions: 5-10 minutos
- Despliegues subsecuentes: 2-3 minutos

## 📋 Checklist

- [ ] Artifact Registry API habilitada
- [ ] Cloud Build API habilitada
- [ ] Cloud Functions API verificada
- [ ] `firebase deploy --only functions` ejecutado

## 🎯 Después del Despliegue

Una vez que el despliegue termine exitosamente, verás:

```
✔  functions[api(us-central1)]: Successful create operation.
✔  functions[syncUserToSupabase(us-central1)]: Successful create operation.
✔  functions[cleanupUserFromSupabase(us-central1)]: Successful create operation.

Function URL (api): https://us-central1-stemforall-f57ac.cloudfunctions.net/api
```

Entonces podrás probar:

```powershell
curl https://us-central1-stemforall-f57ac.cloudfunctions.net/api/health
```

Deberías ver:
```json
{
  "status": "OK",
  "timestamp": "2024-...",
  "service": "Firebase Cloud Functions",
  "version": "2.0.0 (dotenv)"
}
```

---

**Avísame cuando hayas habilitado las 3 APIs y ejecutaremos el despliegue juntos.**
