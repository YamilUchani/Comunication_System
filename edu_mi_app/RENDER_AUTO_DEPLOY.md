# 🚀 AUTO-DEPLOY EN RENDER - GUÍA RÁPIDA

## ⏱️ PROCESO AUTOMÁTICO (2-5 MINUTOS)

### ✅ Si tienes Webhook Configurado

```bash
# 1. Guardar cambios locales
cd backend
git add routes/meetings.js
git commit -m "Fix: Sistema de llamadas - agregar rutas"

# 2. Push a main
git push origin main

# 3. ¡LISTO! Render automáticamente:
#    - Detecta cambio
#    - Inicia build
#    - Deploy
#    - Redeploy completado en 2-5 min
```

### 🔍 Monitorear Deployment

**Opción 1: Render Dashboard**
```
1. Ir a: https://dashboard.render.com
2. Click en servicio "backend"
3. Ver tab "Deployments"
4. Estado actual: debe cambiar
   - "enqueued" → "building" → "live"
5. Esperar verde ✅
```

**Opción 2: Email**
```
Render te enviará email cuando:
- Deploy inicia
- Deploy completado ✅
- Deploy fallido ❌
```

**Opción 3: Git Checkstatus Local**
```bash
# Ver que Git sync correcto
git log --oneline -1
# Debe mostrar: "Fix: Sistema de llamadas..."

# Ver rama
git branch
# Debe mostrar: "* main"

# Ver conexión remoto
git remote -v
# Debe mostrar URL de Render
```

---

## ❌ Si NO tienes Webhook (Deploy Manual)

### Opción A: Desde Render Dashboard (Easiest)

```
1. Ir a https://dashboard.render.com
2. Click servicio "backend"
3. Click en botón azul "Redeploy"
4. Seleccionar rama "main"
5. Click "Deploy now"
6. Esperar ~ 5 minutos
7. Estado debe cambiar a "Live" ✅
```

### Opción B: Desde Terminal (CLI)

```bash
# 1. Instalar Render CLI (si no lo tienes)
npm install -g render-cli

# 2. Login a Render
render login

# 3. Deploy
render deploy --service backend

# 4. Esperar confirmación
```

---

## ✅ VERIFICAR QUE DEPLOYMENT FUE EXITOSO

### Test 1: Health Check (30 seg)
```bash
# Reemplaza [tu-proyecto] con tu Render URL
curl https://[tu-proyecto]-backend.onrender.com/api/health

# Resultado esperado:
# {"status":"OK","timestamp":"2024-04-17T...","environment":"production"}

# ✅ Si ves esto → deployment exitoso
# ❌ Si error 404/500 → deployment fallido
```

### Test 2: Rutas Nuevas Existen (30 seg)

```bash
# Probando que /students-status existe
curl -i https://[tu-proyecto]-backend.onrender.com/api/meetings/test/students-status \
  -H "Authorization: Bearer test"

# Resultado esperado:
# HTTP/1.1 401 Unauthorized
# (o 403, pero NO 404)

# ✅ Si ves 401/403 → ruta EXISTE ✅
# ❌ Si ves 404 → ruta NO existe, redeploy no funcionó
```

### Test 3: Logs (Mientras pruebas de app)

```
1. Render Dashboard → Backend service
2. Click tab "Logs"
3. Buscar con Ctrl+F:
   - "📋" (GET students-status)
   - "📞" (POST entered-call)
   - "🚪" (POST back-to-waiting)

✅ Si ves estos logs → backend responde
❌ Si no ves nada → app no llama API
```

---

## 🎯 PASO A PASO COMPLETO

### 1. Git Push (1 min)
```bash
cd backend
git add routes/meetings.js
git commit -m "Fix: Sistema de llamadas"
git push origin main
```

### 2. Esperar Render (2-5 min)
```
Render automáticamente:
- Detecta push
- Inicia build
- Deploy completed ✅
```

### 3. Verificar Health (30 seg)
```bash
curl https://[ur-backend].onrender.com/api/health
```

### 4. Probar en App (5-10 min)

**Maestro:**
- Entrar a reunión
- Abre panel 👥

**Estudiante:**
- En sala de espera
- Presiona "Llamar maestro" 📞

**Verificar:**
- ✅ Maestro recibe: "🔔 [Nombre] está llamando"
- ✅ Lista se actualiza: 🟠 waiting
- ✅ Maestro presiona admitir
- ✅ Estudiante entra
- ✅ Estado cambia: 🟢 in_call

---

## 🔧 TROUBLESHOOTING RÁPIDO

| Problema | Solución | Tiempo |
|----------|----------|--------|
| "404 Not Found" | Esperar 2 min más o redeploy | 1-5 min |
| "500 Error" | Ver Render Logs → fix → redeploy | 5-15 min |
| "Notificación no llega" | Verificar BACKEND_URL en .env | 2 min |
| "Lista no actualiza" | Revisar Supabase Realtime | 2 min |
| "Estado no cambia" | Verificar RLS policies | 5 min |

---

## 📊 VERIFICAR EN SUPABASE

```sql
-- Ir a Supabase Console → SQL

-- 1. ¿Tabla existe?
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_name = 'meeting_participants'
);
-- Debe retornar: true ✅

-- 2. ¿Campos correctos?
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'meeting_participants';
-- Debe retornar: meeting_id, user_id, last_heartbeat, left_at, joined_at ✅

-- 3. ¿RLS habilitado?
SELECT is_private FROM pg_tables 
WHERE tablename = 'meeting_participants';
-- Debe retornar: true ✅

-- 4. ¿Datos existe?
SELECT COUNT(*) FROM meeting_participants;
-- Debe retornar un número ≥ 0 ✅
```

---

## 📱 ENVIRONMENT VARIABLES EN RENDER

Verificar que están correctos:

```
Render Dashboard → Backend service → Environment
```

**Variables necesarias:**
```env
BACKEND_URL=http://localhost:3000          # ← Cambiar a Render URL
SUPABASE_URL=https://XXXX.supabase.co     # ✅ Debe tener valor
SUPABASE_KEY=eyJXXXXX...                  # ✅ Debe tener valor
NODE_ENV=production                        # ✅ Cambiar a production
TOKEN_EXPIRATION_TIME=3600                # ✅ Recomendado
RATE_LIMIT_MAX_REQUESTS=5000              # ✅ Para API limits
```

**Si necesitas actualizar:**
```
1. Render Dashboard → Backend
2. Tab "Environment"
3. Click value → editar
4. Cambiar valor
5. Click "Save"
6. Redeploy automáticamente
```

---

## 🎉 ¿CÓMO SABER QUE FUNCIONA?

```
✅ SIGNOS DE ÉXITO:

1. Render:
   - Status: "Live" 🟢
   - Health check: 200 OK
   - Logs con "📋", "📞", "🚪"

2. Supabase:
   - SELECT * works
   - Realtime events visible
   - RLS active

3. App:
   - Notificaciones llegan
   - Lista se actualiza
   - Estados cambian
```

---

## ⏳ TIMELINES

| Acción | Tiempo |
|--------|--------|
| Git push → Render detects | Inmediato |
| Build inicia | ~ 30 seg |
| Build completa | ~ 1-2 min |
| Deploy actual | ~ 1-3 min |
| **Total** | **2-5 min** |
| Health check estable | ~ 30 seg después |

---

## 🆘 EMERGENCIA: Rollback

Si algo falla badly:

```bash
# 1. Revertir cambios
git revert HEAD
git push origin main

# 2. Render automáticamente redeploya versión anterior
# (~ 3-5 minutos)

# 3. Verificar que volvió
curl https://[backend]/api/health
```

---

## 📝 CHECKLIST FINAL

- [ ] Git cambios listos (backend/routes/meetings.js)
- [ ] Branch correcto (main)
- [ ] `git push` ejecutado
- [ ] Render Dashboard muestra "Live"
- [ ] Health check OK
- [ ] Logs visible
- [ ] Test app OK
- [ ] Notificaciones llegan
- [ ] Lista actualiza
- [ ] Estados cambian

✅ SI TODAS LAS CASILLAS CHECKED → **DEPLOYMENT EXITOSO** 🎉

---

**Duración total:** 5-15 minutos
**Complejidad:** ⭐⭐ Baja
**Riesgo:** Muy bajo (sin downtime)
**Rollback:** < 5 minutos

