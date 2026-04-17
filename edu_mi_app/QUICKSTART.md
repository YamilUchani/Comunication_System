# 🚀 QUICKSTART - SISTEMA DE LLAMADAS FUNCIONAL

## ⏱️ 5 MINUTOS PARA PONER EN MARCHA

### Paso 1: Reiniciar Backend (30 seg)
```bash
cd backend
npm start
# Espera: "🚀 Servidor corriendo en puerto 3000"
```

### Paso 2: Correr Test (1 min)
```bash
# En otra terminal:
cd backend
node test_student_call_system.js

# Si ves: "✨ TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE!"
# ✅ El backend está funcionando correctamente
```

### Paso 3: Iniciar Frontend (2 min)
```bash
cd lib (o en VSCode)
flutter run -d windows

# O si usas web:
flutter run -d chrome
```

### Paso 4: Hacer una llamada de prueba (2 min)
```
1. Abrir 2 ventanas (o navegadores):
   - Ventana A: Maestro (entra a una reunión)
   - Ventana B: Estudiante (sala de espera)

2. Estudiante presiona botón rojo 📞 (Llamar maestro)

3. ✅ Maestro verá:
   "🔔 [Nombre Estudiante] está llamando desde la sala de espera"

4. Maestro presiona "VER LISTA"

5. Maestro abre panel 👥

6. ✅ En lista aparece estudiante: 
   "🟠 [Nombre] - Sala de espera"

7. Maestro presiona ✅ (Admitir)

8. ✅ Estado cambia a:
   "🟢 [Nombre] - En clase"
```

---

## 🔍 ¿CÓMO VERIFICAR QUE FUNCIONA?

### Backend
```bash
# 1. ¿Servidor corre?
curl http://localhost:3000/api/health

# 2. ¿Rutas existen?
curl http://localhost:3000/api/meetings/test/students-status
# Debe retornar error 404 o sin autenticación, NO "route not found"
```

### Frontend
```
Presiona F12 en el navegador

Busca en Console:
- "📡 Suscribiéndose al canal"
- "📞 Notificación enviada al maestro"
- "getStudentsStatus" o "📋"

Si ves estos mensajes → ✅ Todo funciona
```

### Database
```
Supabase Console → SQL:

SELECT * FROM meeting_participants LIMIT 1;

Debe retornar filas con:
- meeting_id
- user_id
- last_heartbeat (puede ser NULL)
- left_at (puede ser NULL)
```

---

## ⚠️ SI NO FUNCIONA

### Problema: Maestro no recibe notificación
```
PASO 1: Verificar que maestro está en reunión
- ¿Ves la videollamada en pantalla?
- ¿Hay video/audio?

PASO 2: Verificar que estudiante está en sala de espera
- ¿Ves pantalla azul "Esperando Admisión"?

PASO 3: Ejecutar test
node backend/test_student_call_system.js

PASO 4: Revisar logs
Backend console → busca línea con "estudiante X entró"
Frontend console → busca "student_calling"
```

### Problema: Lista no se actualiza
```
PASO 1: Verificar que maestro abrió panel 👥
PASO 2: Esperar 3 segundos (polling automático)
PASO 3: Revisar que Supabase está conectado
- Frontend console → Network tab → busca "subscribe"
PASO 4: Ejecutar comando:
curl http://localhost:3000/api/meetings/[meetingId]/students-status \
  -H "Authorization: Bearer [token]"
```

### Problema: Error en la consola
```
Copiar el error completo

Buscar en DIAGNOSTICO_SISTEMA_LLAMADAS.md 

Si está allí → seguir la solución
Si no está → contactar al desarrollador

Incluir:
- Error exacto
- Logs completos
- Pasos para reproducir
```

---

## 📊 ¿QUÉ DEBERÍA VER?

### MAESTRO
- [x] Videollamada abierta
- [x] Panel de estudiantes con botón 👥
- [x] Notificación cuando estudiante llama
- [x] Lista actualizada cada 3 segundos
- [x] Estados con colores: 🟠 waiting, 🟢 in_call, 🔴 left

### ESTUDIANTE
- [x] Pantalla azul "Esperando Admisión"
- [x] Botón rojo 📞 para llamar
- [x] Notificación "Notificación enviada al maestro"
- [x] Notificación verde cuando lo admiten
- [x] Entra automáticamente a videollamada

---

## 💾 GUARDANDO CAMBIOS

```bash
# Los cambios ya están en:
# backend/routes/meetings.js (~ línea 560, 672, 707)

# Para guardarlos en Git:
git add backend/routes/meetings.js
git commit -m "Fix: Agregar rutas de estado de estudiantes"
git push

# Deploy a Railway:
# Si está configurado con webhook, se redespliega automáticamente
# Si no, ir a Railway dashboard → Deploy manualmente
```

---

## 📞 CONTACTO/AYUDA

Si tienes problemas:

1. **Revisar:** `DIAGNOSTICO_SISTEMA_LLAMADAS.md`
2. **Seguir:** Pasos en `RESUMEN_FIX_DEPLOYMENT.md`
3. **Testear:** `backend/test_student_call_system.js`
4. **Logs:** Buscar "📞", "📋", "🚪" en consolas

---

## ✨ COMANDOS ÚTILES

```bash
# Ver si backend corre
ps aux | grep "node"

# Matar proceso (si está colgado)
pkill node

# Ver logs en tiempo real
npm start  # muestra logs automáticamente

# Correr test de integración
node test_student_call_system.js

# Verificar que Git está sincronizado
git status
git pull origin main
```

---

## 🎉 ¡LISTO!

```
Si pasaste todos estos pasos y funciona:
✅ FELICIDADES - El sistema está operativo

Próximos pasos opcionales:
- Mejorar UI/UX
- Agregar sonidos de notificación
- Optimizar performance
- Agregar tests automáticos
```

---

**Versión:** 1.0
**Última actualización:** 2024-04-17
**Tiempo estimado:** 5 minutos ⏱️
