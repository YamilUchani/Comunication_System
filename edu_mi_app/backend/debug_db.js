require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('❌ Error: Faltan variables de entorno SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY/ANON_KEY');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function testConnection() {
    console.log('🔍 Probando conexión a Supabase...');
    console.log(`URL: ${supabaseUrl}`);

    // 1. Probar lectura de perfiles
    console.log('\n--- Consultando tabla PROFILES ---');
    const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('*');

    if (profilesError) {
        console.error('❌ Error leyendo profiles:', profilesError.message);
    } else {
        console.log(`✅ Profiles encontrados: ${profiles.length}`);
        if (profiles.length > 0) {
            console.table(profiles.map(p => ({
                id: p.user_id,
                email: p.email,
                role: p.role,
                group: p.group_name
            })));
        } else {
            console.log('⚠️ La tabla profiles está vacía (o RLS está ocultando los datos).');
        }
    }

    // 2. Probar lectura de grupos
    console.log('\n--- Consultando tabla GROUPS ---');
    const { data: groups, error: groupsError } = await supabase
        .from('groups')
        .select('*');

    if (groupsError) {
        console.error('❌ Error leyendo groups:', groupsError.message);
    } else {
        console.log(`✅ Grupos encontrados: ${groups.length}`);
        console.table(groups);
    }
}

testConnection();
