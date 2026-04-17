# 🔍 GUÍA DE DIAGNÓSTICO - SISTEMA DE LLAMADAS

## ✅ LISTA DE VERIFICACIÓN RÁPIDA

### 1. ¿Cuál es tu problema?
- [ ] **Problema A:** El maestro NO recibe notificación cuando el estudiante llama
- [ ] **Problema B:** La lista de estudiantes NO se actualiza en el maestro
- [ ] **Problema C:** El estado del estudiante no cambia (siempre aparece "waiting")
- [ ] **Problema D:** Error en la consola/logs

---

## 🐛 DIAGNÓSTICO POR PROBLEMA

### **PROBLEMA A: Maestro NO recibe notificación**

#### 1️⃣ Verificar que el maestro estea EN UNA REUNIÓN
```
Frontend del maestro:
1. ¿Ves la videollamada en pantalla? 
   - SI → continuar paso 2
   - NO → primero únete a una reunión
```

#### 2️⃣ Verificar que el estudiante esté EN SALA DE ESPERA
```
Frontend del estudiante:
1. ¿Ves la pantalla azul "Esperando admisión"?
   - SI → continuar paso 3
   - NO → el estudiante debe estar en la sala de espera
```

#### 3️⃣ Verificar que el estudiante presione "LLAMAR MAESTRO"
```
Frontend del estudiante:
1. Presiona el botón rojo de teléfono (llamar)
2. ¿Ves el mensaje "📞 Notificación enviada al maestro"?
   - SI → continuar paso 4
   - NO → revisar logs del frontend
```

#### 4️⃣ Revisar LOGS DEL BACKEND
```bash
# En terminal del backend:
tail -f logs/*.log  # si tienes logs
# O ver lo que imprime con console.log

Busca líneas como:
- "📋 Obteniendo estado de estudiantes"
- "📞 Estudiante X entró a la llamada"
```

#### 5️⃣ Revisar LOGS DEL FRONTEND (Maestro)
```
En consola del navegador/Dart (F12):
Busca:
- "📡 Suscribiéndose al canal de reunión: meeting:..."
- "🔔 [Estudiante] está llamando"
- "📋 Obteniendo estado de estudiantes"

❌ Si no ves "Suscribiéndose" → el maestro NO está escuchando el canal
```

#### 6️⃣ SOLUCIONES COMUNES

**❌ Problema: No ves "Suscribiéndose al canal"**
- El `meetingId` es NULL
- La videollamada no se inicializó correctamente
- → Reproducir: Cierra y reabre la reunión

**❌ Problema: El evento no llega**
- Verifica que estás usando el MISMO `meetingId` 
- Comprueba conexión a Supabase (revisa errores de red)
- → Comando: en DevTools → Network → busca "subscribe"

---

### **PROBLEMA B: Lista de estudiantes NO se actualiza**

#### 1️⃣ Verificar que el endpoint `/students-status` existe
```bash
# En terminal, hacer petición:
curl -X GET "http://localhost:3000/api/meetings/[meetingId]/students-status" \
  -H "Authorization: Bearer [token]"

# Respuesta esperada:
{
  "students": [
    {"id": "user123", "name": "Juan", "status": "waiting"},
    {"id": "user456", "name": "María", "status": "in_call"}
  ]
}

❌ Si retorna error 404 → La ruta NO se agregó correctamente
```

#### 2️⃣ Verificar que el maestro abrió el panel de estudiantes
```
Frontend del maestro:
1. En la videollamada, busca el botón 👥 (estudiantes)
2. Presionalo para abrir el panel
3. ¿Ves una lista de estudiantes?
   - SI → continuar paso 3
   - NO → revisar que el botón está visible
```

#### 3️⃣ Revisar los logs de actualizaciones
```
Consola del maestro (F12):
Busca: "_fetchStudentsStatus" o "getStudentsStatus"

Debería ver UNA línea cada 3 segundos con actualizaciones
```

#### 4️⃣ Verificar tabla `meeting_participants` en Supabase
```
Ir a Supabase Console → SQL:

SELECT * FROM meeting_participants 
WHERE meeting_id = '[meetingId]'
LIMIT 10;

Debes ver filas con:
- meeting_id
- user_id
- joined_at
- last_heartbeat (debe cambiar)
- left_at

❌ Si está vacío → los estudiantes NO se están registrando
```

---

### **PROBLEMA C: Estado del estudiante NO CAMBIA**

#### Matriz de Diagnóstico:

| Observación | Significado | Solución |
|---|---|---|
| Siempre "🟠 waiting" | `last_heartbeat` es NULL | Ver Problema D |
| Nunca llega a "🟢 in_call" | `/entered-call` no se ejecutó | Revisar logs cuando entra a videollamada |
| Después de salir, stuck en "🟢" | `left_at` no se registró | Revisar cuando presiona "Salir" |

#### 1️⃣ Verificar que `/entered-call` se EJECUTA
```
Consola del estudiante cuando ENTRA a videollamada:
Busca: "📞 Estudiante X entró a la llamada"

❌ Si NO ves esto → la función no se ejecutó
```

#### 2️⃣ Verificar en Supabase que `last_heartbeat` se actualiza
```sql
SELECT user_id, last_heartbeat, LEFT_at 
FROM meeting_participants 
WHERE user_id = '[studentId]' 
ORDER BY updated_at DESC 
LIMIT 1;

-- should show:
-- last_heartbeat: 2024-04-17 15:30:45.000 (reciente)
-- left_at: NULL

❌ Si last_heartbeat es NULL → la actualización NO ocurrió
```

#### 3️⃣ Verificar que el endpoint retorna el estado correcto
```bash
# Después de que estudiante entra a videollamada:
curl -X GET "http://localhost:3000/api/meetings/[meetingId]/students-status" \
  -H "Authorization: Bearer [token]"

# Busca el estudiante:
"status": "in_call"  ✅ Correcto
"status": "waiting"  ❌ Incorrecto - no se actualizó

# Si es incorrecto, revisar que:
# 1. /entered-call devolvió success: true
# 2. La consola del backend dijo "✅ Estado entered-call registrado"
```

---

### **PROBLEMA D: Error en consola**

#### Errores Comunes:

**❌ "TypeError: Cannot read property 'sendBroadcastMessage' of null"**
```
Causa: _realtimeChannel NO se inicializó
Solución: Verificar _setupRealtimeSubscription() en student_waiting_room_screen.dart

Revisar que:
1. meetingId NO es NULL
2. currentUserId NO es NULL
3. Supabase está conectado
```

**❌ "type 'Null' is not a type of 'String'"**
```
Causa: studentName es NULL en payload
Solución: El evento student_calling NO tiene 'student_name'

Revisar en student_waiting_room_screen.dart línea 135:
payload: {
  'student_name': widget.userName,  // ← DEBE tener valor
  ...
}
```

**❌ "CORS error" o "network error"**
```
Causa: Backend NO está accesible o CORS está bloqueado
Solución: 
1. ¿Backend corriendo? npm start en backend/
2. ¿Puerto correcto? .env tiene BACKEND_URL correcto
3. ¿ALLOWED_ORIGINS? Verificar servidor.js línea ~18
```

**❌ "401 Unauthorized" en API call**
```
Causa: Token expirado o NO se pasa correctamente
Solución:
1. Verificar que ApiService._getHeaders() retorna Authorization
2. Token debe empezar con "Bearer "
3. Si está expirado, vuelve a iniciar sesión
```

---

## 🔧 COMANDO PARA PROBAR TODO

```bash
# 1. Asegurar backend corriendo
cd backend
npm start

# 2. En otra terminal, correr test
node test_student_call_system.js

# Salida esperada:
# ✅ Reunión creada
# ✅ Estudiante 1 (waiting) registrado
# ✅ Estudiante 2 (in_call) registrado
# ✅ Estudiante 3 (left) registrado
# 📊 Estados actuales:
#    🟠 test-student-1: waiting
#    🟢 test-student-2: in_call
#    🔴 test-student-3: left
# ✅ Transición completada
# ✅ Estado de student-3 cambiado a "waiting"
# ✨ TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE!
```

---

## 📱 CHECKLIST DE IMPLEMENTACIÓN

- [x] ✅ Backend tiene ruta `GET /meetings/:meetingId/students-status`
- [x] ✅ Backend tiene ruta `POST /meetings/:meetingId/entered-call`
- [x] ✅ Backend tiene ruta `POST /meetings/:meetingId/back-to-waiting-room`
- [ ] Frontend maestro abrió panel de estudiantes
- [ ] Frontend estudiante está en sala de espera
- [ ] Frontend estudiante presionó "Llamar maestro"
- [ ] Maestro recibió notificación
- [ ] Lista de estudiantes se actualiza

---

## 💡 TIPS DE DEBUGGING

### En Supabase Console (SQL)
```sql
-- Ver todas las reuniones activas
SELECT id, channel_name, is_active FROM meetings WHERE is_active = true;

-- Ver participantes de una reunión
SELECT * FROM meeting_participants WHERE meeting_id = 'id123';

-- Ver transiciones de estado recientes
SELECT user_id, last_heartbeat, left_at, updated_at 
FROM meeting_participants 
ORDER BY updated_at DESC 
LIMIT 5;
```

### En Frontend Console (F12)
```javascript
// Ver todos los eventos subscritos
console.log(Supabase.instance.client.getChannels());

// Enviar evento manual (para testing)
channel.sendBroadcastMessage({
  event: 'student_calling',
  payload: {
    'student_name': 'Test Student',
    'user_id': 'test-id',
    'is_auto': false
  }
});
```

### En Backend Console
```bash
# Ver logs en tiempo real
tail -f *.log

# Si usas PM2:
pm2 logs

# Busca líneas con:
# 📋 (get students status)
# 📞 (entered call)
# 🚪 (back to waiting)
```

---

## 📊 ESTADÍSTICAS DE CARGA

Las nuevas rutas son ligeras:

- **GET /students-status**: ~50-100ms (query + mapeo)
- **POST /entered-call**: ~30-50ms (insert/update)
- **POST /back-to-waiting-room**: ~30-50ms (insert/update)

El polling cada 3 segundos = ~20 req/min por maestro = acceptable

---

**Última actualización:** 2024-04-17
**Versión del sistema:** 1.0 (Fix aplicado)
