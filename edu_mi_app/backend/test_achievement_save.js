// Test script para verificar que el backend funciona
// Ejecutar con: node backend/test_achievement_save.js

const http = require('http');

// Test 1: Health check
console.log('🔍 Testing backend health...');
http.get('http://localhost:3000/api/health', (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
        console.log('✅ Backend health:', data);
    });
}).on('error', (err) => {
    console.log('❌ Backend not accessible:', err.message);
});

// Nota: Para probar el endpoint de achievements necesitas:
// 1. Un token de autenticación válido
// 2. Un attendance_id existente
// 3. Un achievement_id existente

console.log('\n📝 Para probar el guardado de logros:');
console.log('1. Verifica que BACKEND_URL en .env apunte a http://localhost:3000');
console.log('2. Revisa la consola del backend (donde ejecutaste npm start)');
console.log('3. Busca logs que digan "PUT /api/attendance/:id/achievements"');
console.log('4. Si no ves esos logs, la petición no está llegando al backend');
