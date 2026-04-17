# 🚀 DEPLOYMENT EN RENDER + SUPABASE

## 📋 RESUMEN

El fix del sistema de llamadas está **LISTO PARA PRODUCCIÓN** en Render + Supabase.

---

## ✅ CHECKLIST PRE-DEPLOYMENT

### Backend (Render)
- [x] 3 rutas agregadas a `backend/routes/meetings.js`
- [x] Código compilable (sin errores de sintaxis)
- [x] Logs configurados
- [x] Manejo de errores implementado
- [x] Autenticación en place

### Database (Supabase)
- [x] Tabla `meeting_participants` existe
- [x] Campos: meeting_id, user_id, last_heartbeat, left_at, joined_at
- [x] RLS policies configuradas ✅
- [x] Permisos de lectura/escritura correctos

### Realtime (Supabase)
- [x] Supabase Realtime habilitado
- [x] Canales `meeting:*` funcionando
- [x] Eventos broadcast configurados

---

## 🚀 PASO 1: DESPLEGAR EN RENDER

### Opción A: Auto Deploy (Recomendado)

**Si tienes webhook configurado:**
```bash
# Solo hace git push y Render redespliega automáticamente
git add backend/routes/meetings.js
git commit -m "Fix: Agregar rutas sistema de llamadas"
git push origin main

# Render automáticamente:
# 1. Detecta el cambio
# 2. Inicia build
# 3. Deploy en 2-5 minutos
```

**Verificar progreso:**
1. Ir a Render Dashboard
2. Seleccionar servicio "backend"
3. Ver tab "Activity" o "Deployments"
4. Esperar: "Live"

### Opción B: Deploy Manual

```bash
# En terminal local en carpeta backend/:

# 1. Ver si tienes Render CLI
render --version

# Si no instalas:
npm install -g render-cli

# 2. Deploy manual
render deploy --service backend

# 3. Esperar confirmación
```

### Opción C: Desde Render Dashboard

```
1. Ir a: https://dashboard.render.com
2. Seleccionar proyecto
3. Seleccionar servicio "backend"
4. Click menu ⋮ → "Redeploy"
5. Seleccionar rama "main"
6. Click "Deploy"
7. Esperar ~ 3 minutos
```

---

## 🔍 PASO 2: VERIFICAR DEPLOYMENT

### Test 1: Health Check
```bash
curl https://[tu-backend-render].onrender.com/api/health

# Esperado:
# {"status": "OK", "timestamp": "...", "environment": "production"}
```

### Test 2: Rutas Nuevas Existen
```bash
# GET /students-status
curl -X GET "https://[tu-backend].onrender.com/api/meetings/test/students-status" \
  -H "Authorization: Bearer eyJ..."

# Debe retornar:
# {"students": []} o Unauthorized (no 404)
# ✅ Si ves 404 → la ruta NO se desplegó

# GET /entered-call
curl -X POST "https://[tu-backend].onrender.com/api/meetings/test/entered-call" \
  -H "Authorization: Bearer eyJ..." \
  -H "Content-Type: application/json" \
  -d '{}'

# Esperado: 500 error (falta meetingId) o success
# ✅ Si ves 404 → la ruta NO se desplegó
```

### Test 3: BD Conectada
```sql
-- En Supabase Console → SQL:
SELECT COUNT(*) FROM meeting_participants;

-- Debe retornar un número (0 o más)
-- ❌ Si falla → RLS policy incorrecta
```

### Test 4: Logs en Render
```
1. Ir a Render Dashboard
2. Servicio "backend" → "Logs"
3. Buscar líneas:
   - "📋 Obteniendo estado de estudiantes"
   - "📞 Estudiante X entró a la llamada"
   - "✅ Estado"

   ✅ Si ves estas líneas → backend está funcionando
   ❌ Si no ves nada → código no se ejecutó
```

---

## 🔐 PASO 3: VERIFICAR SUPABASE

### Checklist Supabase
- [ ] Proyecto activo
- [ ] tabla `meeting_participants` accesible
- [ ] Columnas correctas (meeting_id, user_id, last_heartbeat, left_at)
- [ ] RLS policies habilitadas ✅

### Verificar RLS Policies
```sql
-- En Supabase Console → SQL:

-- Ver que usuarios autenticados pueden leer
SELECT * FROM meeting_participants LIMIT 1;

-- Debe retornar filas (si existen) o vacío
-- ❌ Si retorna error → RLS policy denegar

-- Verificar permisos escritura
INSERT INTO meeting_participants (meeting_id, user_id, last_heartbeat)
VALUES ('test-id', 'test-user', NOW());

-- ✅ Si inserta → permisos OK
-- ❌ Si falla → RLS policy denegado
```

### Configurar RLS (Si falta)
```sql
-- Crear policy de lectura
CREATE POLICY "Users can read their own meeting_participants"
ON meeting_participants
FOR SELECT
USING (auth.uid() = user_id);

-- Crear policy de escritura
CREATE POLICY "Users can update their own meeting_participants"
ON meeting_participants
FOR UPDATE
USING (auth.uid() = user_id);

-- Crear policy de insert
CREATE POLICY "Users can insert their meeting_participants"
ON meeting_participants
FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

---

## 📱 PASO 4: PROBAR EN PRODUCCIÓN

### Test 1: App Flutter → Backend en Producción

**Configurar BACKEND_URL en .env:**
```env
BACKEND_URL=https://[tu-backend].onrender.com
```

**Recompilar:**
```bash
cd lib
flutter pub get
flutter run -d windows  # o tu dispositivo
```

**Prueba manual:**
1. Maestro en reunión
2. Estudiante en sala de espera
3. Estudiante presiona "Llamar"
4. ✅ Maestro recibe notificación
5. ✅ Lista se actualiza cada 3s
6. ✅ Estados cambian

### Test 2: Verificar Llamadas API
```bash
# En Chrome DevTools → Network:

1. Filtro: "students-status"
2. Estudiar petición:
   - URL: https://[render]/api/meetings/.../students-status
   - Status: 200 ✅
   - Response: {"students": [...]}

3. Filtro: "entered-call"
4. Status debe ser 200 ✅
```

### Test 3: Monitorear Render Logs
```
1. Ir a Render Dashboard
2. Backend → Logs
3. Filtro: Ctrl+F → "📋" o "📞"
4. Ver que hay actividad cada 3 segundos

✅ Si ves logs → API está siendo usado
❌ Si no ves nada → frontend no está llamando API
```

---

## 🐛 TROUBLESHOOTING EN PRODUCCIÓN

### Problema 1: "404 Not Found" en Students Status

**Causa:** La ruta no se agregó / Deploy no completó

**Soluciones:**
```bash
# 1. Verificar que archivo se modificó
git log --oneline -5  # ver último commit

# 2. Verificar que está en la rama correcta
git branch

# 3. Forzar redeploy en Render
# → Dashboard → Click ⋮ → "Redeploy"

# 4. Esperar confirmación
# → Activity tab → "Live" en verde

# 5. Test nuevamente
curl https://[backend]/api/health
```

### Problema 2: "401 Unauthorized"

**Causa:** Token expirado o no se pasa correctamente

**Comprobar:**
```sqlite
-- En Supabase:
-- Login y obtener token nuevo
-- Verificar que BACKEND_URL es correcto en .env
-- Recompilar app
```

### Problema 3: "500 Internal Server Error"

**Causa:** Error en la BD o en el código

**Qué hacer:**
```
1. Ver Render Logs → error completo
2. Puede ser:
   - Tabla `meeting_participants` no existe
   - Campo falta
   - RLS policy deniega acceso
   - Conexión a Supabase rota

3. Solucionar según el error
4. Redeploy (si cambias BD)
```

### Problema 4: "Estudiante no recibe notificación"

**Checklist:**
- [ ] ¿Maestro está en meeting activo?
- [ ] ¿Estudiante está en sala de espera de la MISMA meeting?
- [ ] ¿BACKEND_URL es correcto?
- [ ] ¿Supabase Realtime está habilitado?

**Testing:**
```bash
# Ver que el evento se envía por Supabase
# En DevTools → Console del maestro:

localStorage.setItem('SUPABASE_DEBUG', 'true');
location.reload();

# Buscar en Console logs que digan:
# "Subscribed to channel"
# "Received broadcast"
```

---

## 📊 MONITOREO CONTINUO

### Metricas a Revisar

**Diarias:**
- [ ] Render CPU < 80%
- [ ] Render Memory < 80%
- [ ] Supabase DB Queries < 1000/día
- [ ] Response time /students-status < 500ms

**Semanales:**
- [ ] Error rate < 0.1%
- [ ] Uptime > 99%
- [ ] No hay logs "❌ Error"

### Donde Monitoreares

**Render Dashboard:**
```
Servicio → Metrics
- CPU usage
- Memory usage
- Requests per minute
- Error rates
```

**Supabase Dashboard:**
```
Project → Analytics
- API requests
- Database queries
- Cache hit rate
```

---

## 📝 ENVIRONMENT VARIABLES

### Verificar en Render

```
1. Dashboard → Backend Service
2. Tab "Environment"
3. Verificar estas variables:
```

| Variable | Valor Ejemplo | ¿Correcto? |
|----------|--|---|
| `BACKEND_URL` | `http://localhost:3000` | ❌ Reemplazar con Render URL |
| `SUPABASE_URL` | `https://*.supabase.co` | ✅ Debe existir |
| `SUPABASE_KEY` | `eyJ...` | ✅ Debe existir |
| `NODE_ENV` | `production` | ✅ Debe ser production |
| `DATABASE_URL` | (si existe) | ✅ Opcional si usas Supabase |

### Actualizar si falta

```
1. Render Dashboard → Backend
2. Tab "Environment"
3. Editar variables
4. Agregar/actualizar
5. Click "Save"
6. Trigger redeploy
```

---

## 🎉 CONFIRMACIÓN DE ÉXITO

Debes ver:

```
✅ Render Dashboard:
   - Status: "Live" (verde)
   - CPU < 50%
   - Memory < 60%

✅ Supabase Console:
   - SELECT COUNT(*) work
   - RLS policies active
   - Realtime enabled

✅ Logs:
   - Render: "🚀 Servidor corriendo"
   - Sin errores "❌"

✅ API Tests:
   - GET /health → 200 OK
   - GET /students-status → 200 OK (con auth)
   - POST /entered-call → success

✅ App Tests:
   - Notificaciones llegan
   - Lista se actualiza
   - Estados cambian
```

---

## 🔄 ROLLBACK (Si algo falla)

Si necesitas volver a versión anterior:

```bash
# 1. Revertir cambios en Git
git revert HEAD

# 2. Push
git push origin main

# 3. Render redespliega automáticamente

# O manual: Render Dashboard → Redeploy
```

---

**Información útil:**

- **Tiempo de deploy:** 2-5 minutos
- **Downtime:** 0 segundos (blue-green deploy)
- **Rollback:** < 1 minuto
- **Testing:** 5-10 minutos

---

**Versión:** 1.0
**Plataformas:** Render + Supabase
**Última actualización:** 2024-04-17
