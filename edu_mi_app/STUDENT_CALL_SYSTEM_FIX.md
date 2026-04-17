# 🔔 Sistema de Llamadas de Estudiantes - ANÁLISIS Y CORRECCIONES

## ❌ PROBLEMA IDENTIFICADO

El sistema de llamadas de estudiantes NO funcionaba porque **3 rutas críticas del backend NO EXISTÍAN**:

### Rutas Faltantes:
1. `GET /api/meetings/:meetingId/students-status` - Obtener lista de estudiantes con estado
2. `POST /api/meetings/:meetingId/entered-call` - Marcar estudiante DENTRO de llamada
3. `POST /api/meetings/:meetingId/back-to-waiting-room` - Marcar estudiante EN SALA DE ESPERA

---

## ✅ SOLUCIÓN APLICADA

### 1️⃣ **Agregadas 3 nuevas rutas en `backend/routes/meetings.js`**

#### **A) `GET /api/meetings/:meetingId/students-status`**
```javascript
// Obtiene lista completa de estudiantes con su estado actual
// Estados: 'waiting', 'in_call', 'left', 'absent'
// Basado en los datos de meeting_participants table
```

**Lógica:**
- Obtiene el grupo/usuarios permitidos en la reunión
- Consulta tabla `meeting_participants` para ver quién está conectado
- Mapea estado según: `last_heartbeat` (null=waiting, tiene valor=in_call, left_at!=null=left)
- Responde con array: `[{id, name, status}, ...]`

#### **B) `POST /api/meetings/:meetingId/entered-call`**
```javascript
// Marcar que estudiante ENTRÓ a la videollamada
// Actualiza: last_heartbeat = NOW, left_at = null
```

**Cuándo se llama:**
- En `student_video_call_screen.dart` línea 178 → cuando estudiante entra a videollamada
- En `student_waiting_room_screen.dart` línea 300 → cuando estudiante es admitido

#### **C) `POST /api/meetings/:meetingId/back-to-waiting-room`**
```javascript
// Marcar que estudiante REGRESÓ a sala de espera
// Actualiza: last_heartbeat = null, left_at = null
```

**Cuándo se llama:**
- En `student_waiting_room_screen.dart` línea 56 y 153 → cuando estudiante regresa a espera
- En `student_video_call_screen.dart` línea 639 → cuando estudiante vuelve de videollamada

---

## 🔄 FLUJO COMPLETO DEL SISTEMA

### **Desde el lado del ESTUDIANTE:**

```
1. Estudiante en sala de espera → envía broadcast 'student_calling'
   ↓
2. Presiona botón "Llamar Maestro" → _callTeacher()
   ↓
3. Envía evento Supabase: {event: 'student_calling', student_name, user_id}
   ↓
4. Llamada ApiService.setBackToWaitingRoomStatus() → marca como waiting
```

### **Desde el lado del MAESTRO:**

```
1. Maestro subscrito a canal: 'meeting:meetingId'
   ↓
2. Recibe evento 'student_calling' → muestra notificación
   ↓
3. Abre panel de estudiantes → llama _fetchStudentsStatus()
   ↓
4. Llama ApiService.getStudentsStatus(meetingId)
   ↓
5. Backend retorna: [{id, name, status: 'waiting'}, ...]
   ↓
6. Tabla se actualiza cada 3 segundos (polling)
   ↓
7. Maestro presiona "Admitir" → envía evento 'admit_student'
   ↓
8. Estudiante recibe admit → abre VideoCallScreen
```

### **Transición de ESTADOS:**

```
Student → waiting (no heartbeat) → in_call (heartbeat activo) → left (left_at set)
           ↑                            ↓
           └────── back-to-waiting ────┘
```

---

## 📊 TABLA DE ESTADOS EN `meeting_participants`

| Estado | last_heartbeat | left_at | Significado |
|--------|---|---|---|
| **waiting** | NULL | NULL | En sala de espera |
| **in_call** | TIMESTAMP | NULL | En videollamada |
| **left** | (any) | TIMESTAMP | Abandonó |
| **absent** | NULL | NULL | Nunca se unió |

---

## 🧪 CÓMO PROBAR

### **Test 1: Llamada del Estudiante**
1. Estudiante entra a sala de espera de una reunión
2. Presiona botón "Llamar Maestro"
3. ✅ Debería ver: "📞 Notificación enviada al maestro"
4. ✅ Maestro debería ver: "🔔 [Nombre] está llamando desde la sala de espera"

### **Test 2: Actualización de Estado**
1. Maestro abre panel de estudiantes (click en botón de estudiantes)
2. Ver lista con estados correctos:
   - 🟠 Naranja = waiting (sala de espera)
   - 🟢 Verde = in_call (en clase)
   - 🔴 Rojo = left (abandonó)

### **Test 3: Transiciones de Estado**
1. Estudiante está en waiting
2. Maestro presiona "Admitir" → estudiante ve "✅ Admitido"
3. Estudiante entra a videollamada
4. ✅ Estado cambia a 🟢 in_call
5. Estudiante regresa a sala de espera
6. ✅ Estado cambia a 🟠 waiting

---

## 📝 CAMBIOS REALIZADOS

### **backend/routes/meetings.js**
- ✅ Agregada ruta `GET /:meetingId/students-status`
- ✅ Agregada ruta `POST /:meetingId/entered-call`
- ✅ Agregada ruta `POST /:meetingId/back-to-waiting-room`
- Logs detallados para debugging

### **Frontend (SIN CAMBIOS)**
La capa frontend ya estaba correcta:
- `lib/services/api_service.dart` → llamadas al API correcto
- `lib/video_call/video_call_screen.dart` → escucha evento 'student_calling'
- `lib/screens/student_waiting_room_screen.dart` → envía evento y llamadas

---

## 🐛 POSIBLES PROBLEMAS ADICIONALES A REVISAR

1. **¿El maestro NO recibe notificación?**
   - Verificar que el maestro esté en una reunión activa
   - Verificar que estén en el mismo canal Supabase
   - Revisar logs del frontend

2. **¿La lista de estudiantes NO se actualiza?**
   - Verificar que `/students-status` retorna datos
   - Verificar que el maestro abrió el panel de estudiantes
   - Timer de 3 segundos está activo

3. **¿El estado NO cambia a "in_call"?**
   - Verificar que se ejecutó `ApiService.setEnteredCallStatus()`
   - Verificar que `last_heartbeat` se actualizó en BD
   - Revisar logs del backend

---

## 🔗 DEPENDENCIAS

- **Supabase Realtime** → para eventos broadcast (student_calling, admit_student, etc)
- **Agora RTM** → para messages (chat)
- **meeting_participants table** → para registro de estados
- **Backend API** → para CRUD de estados

---

## ✨ Próximos pasos

1. Hacer pruebas completas del flujo
2. Monitorear logs en backend
3. Ajustar tiempos si es necesario (polling cada 3 seg, heartbeat cada X seg)
4. Considerar WebSocket en lugar de polling si hay lag
