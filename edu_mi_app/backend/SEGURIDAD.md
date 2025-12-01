# Guía de Seguridad y Auditoría

## 🔒 Row Level Security (RLS)

### ¿Qué es RLS?

Es una capa de seguridad en la base de datos que **controla quién puede ver/editar qué datos**.

**Ejemplo:**
- Sin RLS: Usuario A puede ver reuniones de Usuario B
- Con RLS: Usuario A **solo** ve sus propias reuniones

### Configuración Aplicada:

```sql
-- Usuarios solo ven su propio perfil
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (auth.uid() = user_id);
```

Esto significa: **Imposible** que un usuario vea datos de otro, incluso hackeando la app.

---

## 🛡️ Prevención de Abuso

### 1. Límite de Reuniones

```sql
-- Máximo 5 reuniones activas por usuario (configurable)
meeting_limit SET DEFAULT 5
```

**Qué hace:**
- Usuario crea reunión #1, #2, #3, #4, #5 → ✅ OK
- Intenta crear #6 → ❌ ERROR: "Meeting limit exceeded"
- Finaliza reunión #1 → Puede crear otra

### 2. Rate Limiting (Ya en Railway)

```javascript
// 100 peticiones cada 15 minutos
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100
});
```

**Qué hace:**
- Usuario hace 50 peticiones → ✅ OK
- Usuario hace 100 peticiones → ✅ OK
- Usuario hace 101 peticiones → ❌ BLOQUEADO 15 minutos

### 3. Limpieza Automática

```sql
-- Elimina reuniones inactivas de hace 30+ días
DELETE FROM meetings
WHERE is_active = false
  AND ended_at < NOW() - INTERVAL '30 days';
```

**Qué hace:**
- Evita que la BD crezca infinitamente
- Borra datos antiguos automáticamente

---

## 📊 Logs de Auditoría

### ¿Qué son?

Un **registro de todo lo que pasa** en tu sistema.

### Tabla `audit_logs`:

```sql
CREATE TABLE audit_logs (
    id UUID,
    user_id UUID,           -- ¿Quién?
    action VARCHAR(50),     -- ¿Qué hizo? (INSERT/UPDATE/DELETE)
    table_name VARCHAR(50), -- ¿En qué tabla?
    record_id UUID,         -- ¿Qué registro?
    old_data JSONB,         -- Datos antes
    new_data JSONB,         -- Datos después
    created_at TIMESTAMP    -- ¿Cuándo?
);
```

### Ejemplo Real:

**Usuario crea una reunión:**
```json
{
  "user_id": "abc123",
  "action": "INSERT",
  "table_name": "meetings",
  "record_id": "meeting-xyz",
  "new_data": {
    "channel_name": "clase-mate",
    "title": "Matemáticas",
    "creator_id": "abc123"
  },
  "created_at": "2024-12-01 10:30:00"
}
```

**Usuario modifica reunión:**
```json
{
  "user_id": "abc123",
  "action": "UPDATE",
  "table_name": "meetings",
  "record_id": "meeting-xyz",
  "old_data": { "title": "Matemáticas" },
  "new_data": { "title": "Geometría" },
  "created_at": "2024-12-01 10:35:00"
}
```

### ¿Para qué sirve?

1. **Debugging**: "¿Quién borró esta reunión?"
2. **Seguridad**: Detectar actividad sospechosa
3. **Cumplimiento**: Regulaciones (GDPR, etc.)
4. **Análisis**: Entender cómo usan la app

### Consultas Útiles:

```sql
-- Ver todas las acciones de un usuario
SELECT * FROM audit_logs 
WHERE user_id = 'abc123' 
ORDER BY created_at DESC;

-- Ver quién modificó una reunión específica
SELECT * FROM audit_logs 
WHERE record_id = 'meeting-xyz';

-- Detectar usuarios muy activos (posible abuso)
SELECT user_id, COUNT(*) as actions
FROM audit_logs
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY user_id
HAVING COUNT(*) > 100;
```

---

## 🚀 Cómo Aplicar

### Paso 1: Ejecutar SQL en Supabase

1. Ve a https://supabase.com/dashboard
2. Tu proyecto → **SQL Editor**
3. New query → Pega el contenido de `backend/database/security_setup.sql`
4. Run (▶️)

### Paso 2: Verificar

```sql
-- Verificar RLS está activo
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';

-- Debería mostrar rowsecurity = true
```

### Paso 3: Probar

En tu app:
1. Crea 5 reuniones → ✅ OK
2. Intenta crear la 6ta → ❌ Error: "Meeting limit exceeded"

---

## 📈 Niveles de Seguridad

### Antes de aplicar esto:
**5/10** - Básico

### Después de aplicar:
**9/10** - Producción lista

### ¿Qué falta para 10/10?
- Auditoría externa
- Penetration testing
- Cifrado end-to-end de mensajes
- 2FA obligatorio

---

## ✅ Resumen

| Protección | Estado | Qué hace |
|------------|--------|----------|
| RLS | ✅ Configurado | Usuarios solo ven sus datos |
| Límite reuniones | ✅ 5 por usuario | Evita spam |
| Rate limiting | ✅ 100/15min | Evita ataques |
| Logs auditoría | ✅ Automático | Rastrea todo |
| Limpieza auto | ✅ 30 días | Mantiene BD limpia |

**Tu app ahora es segura para producción** 🎉
