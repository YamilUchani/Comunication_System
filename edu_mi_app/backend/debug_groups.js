require('dotenv').config();
const supabase = require('./config/supabase');

async function diagnose() {
    console.log('🔍 Iniciando diagnóstico de Grupos y Miembros...\n');

    // 1. Obtener todos los grupos
    const { data: groups, error: groupsError } = await supabase
        .from('groups')
        .select('name, display_name');

    if (groupsError) {
        console.error('❌ Error obteniendo grupos:', groupsError);
        return;
    }
    console.log(`📋 Grupos encontrados (${groups.length}):`);
    groups.forEach(g => console.log(`   - Name: "${g.name}", Display: "${g.display_name}"`));

    console.log('\n-----------------------------------\n');

    // 2. Obtener todos los perfiles con su group_name
    const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('full_name, group_name, role');

    if (profilesError) {
        console.error('❌ Error obteniendo perfiles:', profilesError);
        return;
    }

    console.log(`👥 Perfiles encontrados (${profiles.length}):`);
    profiles.forEach(p => {
        const groupMatch = groups.find(g => g.name === p.group_name);
        const status = groupMatch ? '✅ Match' : '⚠️ Sin Match';
        console.log(`   - Usuario: "${p.full_name}" | Rol: ${p.role} | Grupo: "${p.group_name}" -> ${status}`);
    });
}

diagnose();
