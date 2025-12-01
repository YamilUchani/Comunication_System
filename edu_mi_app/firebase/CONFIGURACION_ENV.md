# Guía Actualizada: Firebase Functions con .env (Nuevo Método)

## ⚠️ CAMBIO IMPORTANTE

Firebase deprecó `functions.config()`. Ahora usamos archivos `.env` (el método moderno y estándar).

## 🔧 Nueva Configuración

### Paso 1: Crear archivo .env en Functions

```powershell
cd firebase/functions

# Copiar el template
cp .env.example .env

# Editar con tus credenciales
notepad .env
```

### Paso 2: Completar el archivo .env

Edita `firebase/functions/.env`:

```env
# Supabase (obtén de https://supabase.com > Settings > API)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGc...

# Agora (obtén de https://console.agora.io)
AGORA_APP_ID=tu_app_id_aqui
AGORA_APP_CERTIFICATE=tu_certificado_aqui
```

### Paso 3: Instalar dependencias

```powershell
cd firebase/functions
npm install
```

Esto instalará `dotenv` automáticamente.

### Paso 4: Desplegar

```powershell
cd ../..  # Volver a la raíz
firebase deploy --only functions
```

Firebase automáticamente subirá el archivo `.env` con las functions.

## ✅ Ventajas del Nuevo Método

| Aspecto | Antes (functions.config) | Ahora (.env) |
|---------|-------------------------|--------------|
| Configuración | `firebase functions:config:set` | Archivo `.env` |
| Local | Descargar config manual | Solo `.env` |
| Estándar | Firebase específico | ✅ Estándar Node.js |
| Futuro | ❌ Deprecado 2026 | ✅ Soportado |
| Consistencia | Diferente en local/prod | ✅ Mismo archivo |

## 🔄 Migración desde functions.config()

Si ya configuraste con el método antiguo:

```powershell
# 1. Exportar configuración existente
firebase functions:config:get > config.json

# 2. Crear .env manualmente basándote en config.json
notepad firebase/functions/.env

# 3. Copiar los valores al formato .env:
# SUPABASE_URL=...
# SUPABASE_SERVICE_KEY=...
# etc.

# 4. Redesplegar
firebase deploy --only functions
```

## 🧪 Probar Localmente

```powershell
# El emulador usa tu .env automáticamente
firebase emulators:start --only functions
```

## 🔐 Seguridad

**IMPORTANTE:** El archivo `.env` contiene credenciales sensibles.

✅ **Hacer:**
- Agregar `.env` al `.gitignore` (ya está)
- Mantener `.env.example` sin valores reales
- Usar valores diferentes en local y producción

❌ **NO hacer:**
- Subir `.env` a Git
- Compartir tu `.env`
- Hardcodear credenciales en el código

## 📝 Checklist de Migración

- [ ] Crear `firebase/functions/.env`
- [ ] Copiar valores de Supabase
- [ ] Copiar valores de Agora
- [ ] `npm install` en functions
- [ ] Probar localmente con emulador
- [ ] Desplegar functions
- [ ] Verificar health check
- [ ] Probar crear reunión

## 🐛 Solución de Problemas

### Error: "SUPABASE_URL is required"

Tu archivo `.env` no se está cargando. Verifica:
1. Está en `firebase/functions/.env`
2. No tiene errores de sintaxis
3. No tiene espacios extras

### Error al desplegar

```powershell
# Verificar que .env existe
cat firebase/functions/.env

# Reinstalar dependencias
cd firebase/functions
rm -rf node_modules package-lock.json
npm install
cd ../..

# Redesplegar
firebase deploy --only functions
```

### Emulador no lee .env

El emulador lee `.env` automáticamente. Si no funciona:
1. Verifica que esté en la ruta correcta
2. Reinicia el emulador
3. Verifica sintaxis del archivo

## 📚 Diferencias en el Código

### Antes (Deprecado):
```javascript
const supabaseUrl = functions.config().supabase.url;
const supabaseKey = functions.config().supabase.service_key;
```

### Ahora (Moderno):
```javascript
import dotenv from 'dotenv';
dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
```

## ✨ Ejemplo Completo de .env

```env
# Supabase
SUPABASE_URL=https://abcdefghijk.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Agora  
AGORA_APP_ID=1234567890abcdef
AGORA_APP_CERTIFICATE=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

# Opcional: Configuración adicional
NODE_ENV=production
LOG_LEVEL=info
```

---

**Versión actualizada:** Migrado a dotenv (Firebase Functions 2.0)  
**Fecha:** Noviembre 2024  
**Estado:** ✅ Listo para producción hasta 2030+
