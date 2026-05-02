# ✅ CHECKLIST DE PRUEBAS POST-CORRECCIONES

Use este documento para validar que todas las correcciones fueron aplicadas correctamente.

---

## 📋 CHECKLIST PRE-CORRECCIONES

Hacer esto ANTES de aplicar cualquier cambio:

- [ ] **Backup:** Hacer git commit de estado actual
  ```bash
  git add .
  git commit -m "backup: estado pre-correcciones"
  git push
  ```

- [ ] **Branch:** Crear rama para cambios
  ```bash
  git checkout -b fix/memory-leaks-cleanup
  ```

- [ ] **Verificar dependencias:**
  ```bash
  flutter pub get
  # En backend:
  npm install
  ```

---

## 🧪 PRUEBAS UNITARIAS

### Test 1: Limpieza de Timers

**Objetivo:** Verificar que los timers se cancelan al cerrar la pantalla

**Pasos:**
1. Abre la app
2. Inicia sesión como maestro
3. Crea una reunión
4. Abre panel de estudiantes (para que inicie el timer)
5. Presiona atrás o cierra la ventana

**Esperado:**
- ✅ En consola debe decir: "Timers cancelados"
- ✅ DevTools (Memory) no muestra aumento de memory después de cerrar
- ✅ No hay errores en la consola

**Verificación de código:**
```dart
// Busca en video_call_screen.dart:
@override
void dispose() {
  _autoStudentRefreshTimer?.cancel();  // ✅ DEBE estar
  _studentsTimer?.cancel();             // ✅ DEBE estar
  // ...
}
```

---

### Test 2: Unsubscribe de Channels

**Objetivo:** Verificar que los canales realtime se cierran

**Pasos:**
1. Abre reunión como maestro
2. Espera 5 segundos
3. Cierra la reunión

**Esperado:**
- ✅ Console: "Meeting channel unsubscribed"
- ✅ No hay eventos fantasma después
- ✅ En Supabase logs (si tienes acceso): canales cerrados

**Verificación de código:**
```dart
// Busca en video_call_screen.dart dispose():
_meetingChannel?.unsubscribe();  // ✅ DEBE estar
```

---

### Test 3: Dispose del VideoCallController

**Objetivo:** Verificar que Agora se desconecta correctamente

**Pasos:**
1. Inicia videollamada
2. Espera 3 segundos
3. Presiona "Salir"

**Esperado:**
- ✅ Console: "Agora engine destruido" o similar
- ✅ Micrófono y cámara se apagan
- ✅ No hay ruido o lag después de salir

**Verificación de código:**
```dart
// Busca en video_call_controller.dart:
Future<void> leaveAndDispose() async {  // ✅ DEBE existir
  await _engine.leaveChannel();
  await _engine.release(sync: true);
}
```

---

### Test 4: Validación de Payloads

**Objetivo:** Verificar que eventos malformados no crashean

**Pasos:**
1. En backend test_script.js, enviar payload con estructura incorrecta:
   ```javascript
   // Enviar evento SIN student_name
   channel.sendBroadcastMessage({
     event: 'student_calling',
     payload: { /* vacío */ }
   });
   ```
2. Ver si la app crashea

**Esperado:**
- ✅ No crashea
- ✅ Console: "⚠️ student_name inválido"
- ✅ Sigue funcionando normalmente

**Verificación de código:**
```dart
// Busca en video_call_screen.dart _setupMeetingChannel():
if (payload is! Map<String, dynamic>) {  // ✅ DEBE estar
  print('⚠️ Payload inválido');
  return;
}
```

---

### Test 5: Error Handling en Session Service

**Objetivo:** Verificar que acceptUser() maneja errores

**Pasos:**
1. Como admin, intentar admitir un estudiante
2. A mitad del proceso, "desconectar" Supabase (cambiar red)
3. Reconectar

**Esperado:**
- ✅ Si falla, mostrar error al usuario
- ✅ No quedar en estado inconsistente
- ✅ Console tiene logs detallados

---

### Test 6: Validación de BACKEND_URL

**Objetivo:** Verificar que falta de BACKEND_URL se captura

**Pasos:**
1. Comentar BACKEND_URL en .env
2. Iniciar app
3. Intentar crear reunión o cualquier API call

**Esperado:**
- ✅ Mostrar error claro: "BACKEND_URL no configurado"
- ✅ No: "Cannot read property of undefined"

---

## 🔄 PRUEBAS DE FLUJO COMPLETO

### Flujo 1: Estudiante → Sala Espera → Admitir → Videollamada

**Pasos:**
1. **Maestro:** Inicia sesión y abre una reunión
2. **Estudiante:** Entra a la reunión
3. **Estudiante:** Ve sala de espera, presiona "Llamar Maestro"
4. **Maestro:** Recibe notificación en tiempo real
5. **Maestro:** Abre panel de estudiantes y presiona "Admitir"
6. **Estudiante:** Ve "✅ Admitido" y videollamada abre automáticamente
7. **Ambos:** Ven video/audio del otro
8. **Ambos:** Presionan "Salir"

**Verificaciones:**
- [ ] Notificación llega en tiempo real (< 1 segundo)
- [ ] Estados en BD actualizan correctamente
- [ ] Video/audio sin lag
- [ ] No hay crashes al salir
- [ ] Memory limpio después de salir

**Logs esperados:**
```
Maestro console:
✅ Suscrito al canal de reunión
✅ Evento student_calling recibido
✅ Notificación mostrada

Estudiante console:
✅ Suscrito al canal de reunión
✅ Evento admit_student recibido
✅ Videollamada abierta
```

---

### Flujo 2: Expulsión de Estudiante

**Pasos:**
1. Seguir Flujo 1 hasta paso 6 (ambos en videollamada)
2. **Maestro:** Abre panel de estudiantes
3. **Maestro:** Presiona "Expulsar" en un estudiante
4. **Estudiante:** Ve "⛔ Has sido removido"
5. **Estudiante:** Ventana se cierra automáticamente

**Verificaciones:**
- [ ] Estudiante recibe evento en tiempo real
- [ ] Ventana cierra correctamente
- [ ] Estado en BD: "left_at" se actualiza
- [ ] Maestro ve al estudiante como "removido"

---

### Flujo 3: Estudiante Regresa a Sala Espera

**Pasos:**
1. Estudiante en videollamada
2. Presiona botón "Regresar a Sala de Espera"
3. Regresa a StudentWaitingRoomScreen
4. Maestro ve que estado cambió

**Verificaciones:**
- [ ] Estado en BD: last_heartbeat = null, left_at = null
- [ ] Maestro ve estado: "🟠 waiting"
- [ ] Puede ser admitido de nuevo

---

### Flujo 4: Chat entre Maestro y Estudiante

**Pasos:**
1. Ambos en videollamada
2. Estudiante abre panel de chat
3. Envía mensaje "Hola maestro"
4. Maestro lo recibe (o vice versa)

**Verificaciones:**
- [ ] Mensaje llega en < 1 segundo
- [ ] Solo se reciben mensajes del maestro (no de otros estudiantes)
- [ ] Notificación se muestra
- [ ] Sin errores de encoding

---

## 🚀 PRUEBAS DE ESTRÉS

### Stress Test 1: Múltiples Estudiantes

**Objetivo:** Verificar que no hay leaks con muchos estudiantes

**Setup:**
- 1 maestro
- 5+ estudiantes simultáneamente

**Pasos:**
1. Maestro abre reunión
2. 5 estudiantes entran a sala de espera
3. Todos presionan "Llamar Maestro" simultáneamente
4. Maestro admite a todos

**Verificaciones:**
- [ ] Todos reciben notificación
- [ ] Maestro ve lista de 5 estudiantes
- [ ] Todos pueden entrar a videollamada
- [ ] DevTools Memory: sin spikes anormales

**Monitoreo en DevTools:**
```
Memory después de 10 min:
- Inicial: ~150MB
- Después stress: ~200MB (normal)
- ❌ Si llega a >500MB: hay leak
```

---

### Stress Test 2: Reconnect con Mala Red

**Objetivo:** Verificar que reconecta correctamente

**Pasos:**
1. Videollamada activa
2. Desactivar WiFi / cambiar a datos
3. Esperar 5 segundos
4. Reactivar WiFi

**Esperado:**
- [ ] Notificación: "Reconectando..."
- [ ] Se reconecta automáticamente
- [ ] Video vuelve después de 2-3 seg
- [ ] Sin crashes

---

### Stress Test 3: Cierre Rápido de Pantallas

**Objetivo:** Verificar que cleanup es robusto

**Pasos:**
1. Abre videollamada
2. Presiona atrás rápidamente 5 veces
3. Cierra la app (Alt+F4 o botón X)

**Esperado:**
- [ ] No crashea
- [ ] No hay errores en consola
- [ ] Procesos secundarios se cierran

---

## 🔍 VERIFICACIÓN DE LOGS

### Log Check 1: Console limpia sin errores

**Después de ejecutar todos los flujos, buscar:**

```bash
# ❌ NO debe haber:
TypeError
Null check operator
_CastError
Cannot read property of undefined
Unhandled exception

# ✅ Debe haber (ocasionalmente):
✅
✅ (indica operaciones exitosas)
```

---

### Log Check 2: Timers se cancelan

**Buscar en console:**
```
🧹 [VIDEO_CALL_SCREEN] Iniciando dispose...
✅ Timers cancelados
✅ Meeting channel unsubscribed
✅ VideoCallController disposed
🧹 [VIDEO_CALL_SCREEN] Dispose completado
```

---

### Log Check 3: No hay memory leaks

**En DevTools Memory profiler:**
1. Abre reunión
2. Cierra reunión
3. Fuerza garbage collection (botón)
4. Memoria debe bajar cerca del nivel inicial

```
Inicial:     150 MB
+ Reunión:   250 MB
- Cierra:    170 MB (cerca del inicial)
✅ Correcto

Inicial:     150 MB
+ Reunión:   250 MB
- Cierra:    400 MB (aumento anormal)
❌ Hay leak
```

---

## 📊 MATRIZ DE PRUEBAS

| Test | Esperado | Actual | Pasó | Notas |
|------|----------|--------|------|-------|
| 1. Limpieza de timers | Console muestra ✅ | | ☐ | |
| 2. Unsubscribe channels | No eventos fantasma | | ☐ | |
| 3. Dispose controller | Agora destruido | | ☐ | |
| 4. Validación payloads | No crashea | | ☐ | |
| 5. Error handling | Mostrar error a usuario | | ☐ | |
| 6. BACKEND_URL | Mensaje claro | | ☐ | |
| 7. Flujo completo | Todos los estados | | ☐ | |
| 8. Expulsión | Estudiante sale | | ☐ | |
| 9. Regresar a espera | Estado correcto | | ☐ | |
| 10. Chat | Mensajes llegan | | ☐ | |
| 11. Stress 5 estudiantes | Sin leaks | | ☐ | |
| 12. Reconnect red | Se reconecta | | ☐ | |
| 13. Cierre rápido | Sin crashes | | ☐ | |
| 14. Console limpia | No errores | | ☐ | |
| 15. Memory leak check | No aumento anormal | | ☐ | |

---

## 🎯 CRITERIO DE ACEPTACIÓN

### ✅ LISTO PARA PRODUCCIÓN si:

- [ ] Todos los 15 tests pasan ✅
- [ ] No hay errores en console
- [ ] Memory profile limpio
- [ ] Flujos completos sin crashes
- [ ] Logs muestran cleanup correcto
- [ ] Stress tests completados
- [ ] Code review de cambios

### ❌ NO LISTO si:

- [ ] Algún test falla
- [ ] Hay TypeErrors o crasheos
- [ ] Memory aumenta continuamente
- [ ] Procesos no se limpian
- [ ] Errores silenciosos en logs

---

## 📝 HOJA DE PRUEBAS

Imprimir o copiar para cada ronda de pruebas:

```
Fecha: _______________
Tester: _______________
Compilador usado: ☐ debug ☐ release
Plataforma: ☐ Windows ☐ Android ☐ iOS

Test 1 (Timers): ☐ Pasó  ☐ Falló
Notas: _______________________________________________

Test 2 (Channels): ☐ Pasó  ☐ Falló
Notas: _______________________________________________

Test 3 (Controller): ☐ Pasó  ☐ Falló
Notas: _______________________________________________

... (continuar para todos)

Memory leak check: 
Inicial: ___ MB
Post-test: ___ MB
Diferencia: ___ MB (debe ser <100)
☐ OK  ☐ FALLA

Firma: _______________________
```

---

## 🔄 PROCEDIMIENTO DE REGRESIÓN

Si algún test falla:

1. **Identifica el problema:**
   - Revisar el log exacto del error
   - Ir a REVISION_COMPLETA_APLICACION.md y buscar el problema
   - Revisar CORRECCIONES_CODIGO.md para ese archivo

2. **Revisa el cambio:**
   - ¿Se copió correctamente?
   - ¿Falta alguna línea?
   - ¿Hay typos o indentación?

3. **Rollback si es necesario:**
   ```bash
   git checkout -- <archivo>
   # Reintentar el cambio más cuidadosamente
   ```

4. **Re-test:**
   - Después de cada fix, rerun el test

---

## ✨ POST-CORRECCIONES

Cuando TODO pase:

1. **Commit:**
   ```bash
   git add .
   git commit -m "fix: memory leaks y error handling

   - Agregar cleanup de timers en video_call_screen
   - Unsubscribe de realtime channels
   - Dispose seguro del VideoCallController
   - Validación de payloads
   - Error handling mejorado
   - Tests completados exitosamente"
   ```

2. **Push:**
   ```bash
   git push origin fix/memory-leaks-cleanup
   ```

3. **Merge:**
   ```bash
   git checkout main
   git merge fix/memory-leaks-cleanup
   git push origin main
   ```

4. **Deploy:**
   - Si tienes CD configurado, esto trigueará un deploy automático
   - Si no, deploy manualmente a producción

---

## 📞 SOPORTE

Si algo falla:

1. Revisar [REVISION_COMPLETA_APLICACION.md](REVISION_COMPLETA_APLICACION.md)
2. Revisar [CORRECCIONES_CODIGO.md](CORRECCIONES_CODIGO.md)
3. Revisar logs en DevTools
4. Revisar backend logs (si aplica)

---

**Última actualización:** 18 Abril 2026

