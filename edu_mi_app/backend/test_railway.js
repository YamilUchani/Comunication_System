// Script para probar el servidor Railway
const https = require('https');

const RAILWAY_URL = 'https://redirectional-production.up.railway.app';

function testEndpoint(path, description) {
    return new Promise((resolve, reject) => {
        console.log(`\n🔍 Probando: ${description}`);
        console.log(`   URL: ${RAILWAY_URL}${path}`);

        https.get(`${RAILWAY_URL}${path}`, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                console.log(`   Status: ${res.statusCode}`);
                if (res.statusCode === 200) {
                    try {
                        const json = JSON.parse(data);
                        console.log(`   ✅ Respuesta:`, JSON.stringify(json, null, 2).substring(0, 200));
                        resolve({ success: true, data: json });
                    } catch (e) {
                        console.log(`   ✅ Respuesta (texto):`, data.substring(0, 200));
                        resolve({ success: true, data });
                    }
                } else {
                    console.log(`   ❌ Error ${res.statusCode}:`, data.substring(0, 200));
                    resolve({ success: false, status: res.statusCode, data });
                }
            });
        }).on('error', (err) => {
            console.log(`   ❌ Error de conexión:`, err.message);
            reject(err);
        });
    });
}

async function runTests() {
    console.log('='.repeat(60));
    console.log('VERIFICACIÓN DEL SERVIDOR RAILWAY');
    console.log('='.repeat(60));

    // Test 1: Health check
    await testEndpoint('/api/health', 'Health Check');

    console.log('\n' + '='.repeat(60));
    console.log('RESUMEN');
    console.log('='.repeat(60));
    console.log('\nSi ves ✅ en todos los tests, Railway está configurado correctamente.');
    console.log('Si ves ❌, revisa las variables de entorno en Railway.\n');
}

runTests().catch(console.error);
