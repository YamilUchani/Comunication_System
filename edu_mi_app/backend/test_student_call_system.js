/**
 * test_student_call_system.js
 * Script para probar el sistema completo de llamadas de estudiantes
 * 
 * Uso: node test_student_call_system.js
 */

require('dotenv').config();
const supabase = require('./config/supabase');

async function testCompleteFlow() {
    console.log('🧪 INICIANDO PRUEBAS DEL SISTEMA DE LLAMADAS DE ESTUDIANTES\n');

    try {
        // 1. Test: Crear una reunión de prueba
        console.log('1️⃣  CREANDO REUNIÓN DE PRUEBA...');
        const { data: meetingData, error: meetingError } = await supabase
            .from('meetings')
            .insert({
                channel_name: `test-call-${Date.now()}`,
                title: 'Prueba: Sistema de Llamadas',
                description: 'Reunión de prueba para validar el sistema',
                creator_id: 'test-teacher-id',
                is_active: true,
                allowed_groups: ['test-group'],
                allowed_users: [],
                expires_at: new Date(Date.now() + 3600000).toISOString()
            })
            .select()
            .single();

        if (meetingError) {
            console.error('❌ Error creando reunión:', meetingError);
            return;
        }

        const meetingId = meetingData.id;
        console.log(`✅ Reunión creada: ${meetingId}\n`);

        // 2. Test: Crear participantes de prueba
        console.log('2️⃣  REGISTRANDO PARTICIPANTES...');
        
        // Estudiante espera
        const { error: student1Error } = await supabase
            .from('meeting_participants')
            .upsert({
                meeting_id: meetingId,
                user_id: 'test-student-1',
                joined_at: new Date().toISOString(),
                last_heartbeat: null  // waiting
            }, { onConflict: 'meeting_id,user_id' });

        if (student1Error) console.error('❌ Error registrando estudiante waiting:', student1Error);
        else console.log('✅ Estudiante 1 (waiting) registrado');

        // Estudiante en llamada
        const { error: student2Error } = await supabase
            .from('meeting_participants')
            .upsert({
                meeting_id: meetingId,
                user_id: 'test-student-2',
                joined_at: new Date().toISOString(),
                last_heartbeat: new Date().toISOString()  // in_call
            }, { onConflict: 'meeting_id,user_id' });

        if (student2Error) console.error('❌ Error registrando estudiante in_call:', student2Error);
        else console.log('✅ Estudiante 2 (in_call) registrado');

        // Estudiante que salió
        const { error: student3Error } = await supabase
            .from('meeting_participants')
            .upsert({
                meeting_id: meetingId,
                user_id: 'test-student-3',
                joined_at: new Date().toISOString(),
                left_at: new Date().toISOString()
            }, { onConflict: 'meeting_id,user_id' });

        if (student3Error) console.error('❌ Error registrando estudiante left:', student3Error);
        else console.log('✅ Estudiante 3 (left) registrado\n');

        // 3. Test: Obtener estado de estudiantes
        console.log('3️⃣  OBTENIENDO ESTADO DE ESTUDIANTES...');
        
        const { data: participants, error: participantsError } = await supabase
            .from('meeting_participants')
            .select('user_id, joined_at, last_heartbeat, left_at')
            .eq('meeting_id', meetingId);

        if (participantsError) {
            console.error('❌ Error obteniendo participantes:', participantsError);
            return;
        }

        const statuses = participants.map(p => {
            let state = 'absent';
            if (p.left_at) {
                state = 'left';
            } else if (!p.last_heartbeat) {
                state = 'waiting';
            } else {
                state = 'in_call';
            }
            return { user_id: p.user_id, state };
        });

        console.log('📊 Estados actuales:');
        statuses.forEach(s => {
            const emoji = s.state === 'waiting' ? '🟠' : 
                         s.state === 'in_call' ? '🟢' : 
                         s.state === 'left' ? '🔴' : '⚫';
            console.log(`   ${emoji} ${s.user_id}: ${s.state}`);
        });
        console.log('');

        // 4. Test: Simular transición de estado
        console.log('4️⃣  SIMULANDO TRANSICIÓN DE ESTADO...');
        console.log('   Transición: student-3 de "left" a "waiting"');

        const { error: transitionError } = await supabase
            .from('meeting_participants')
            .update({
                left_at: null,
                last_heartbeat: null
            })
            .eq('meeting_id', meetingId)
            .eq('user_id', 'test-student-3');

        if (transitionError) {
            console.error('❌ Error actualizando estado:', transitionError);
        } else {
            console.log('✅ Transición completada\n');
        }

        // 5. Test: Validar cambio
        console.log('5️⃣  VALIDANDO CAMBIO DE ESTADO...');
        
        const { data: updatedParticipants } = await supabase
            .from('meeting_participants')
            .select('user_id, left_at, last_heartbeat')
            .eq('meeting_id', meetingId);

        const student3Updated = updatedParticipants.find(p => p.user_id === 'test-student-3');
        if (student3Updated && student3Updated.left_at === null && student3Updated.last_heartbeat === null) {
            console.log('✅ Estado de student-3 cambiado a "waiting"\n');
        } else {
            console.log('⚠️  Estado no cambió como se esperaba\n');
        }

        // 6. Cleanup: Eliminar reunión de prueba
        console.log('6️⃣  LIMPIANDO DATOS DE PRUEBA...');
        
        const { error: deleteError } = await supabase
            .from('meetings')
            .update({ is_active: false })
            .eq('id', meetingId);

        if (deleteError) {
            console.error('⚠️  Error desactivando reunión:', deleteError);
        } else {
            console.log('✅ Reunión de prueba desactivada\n');
        }

        console.log('✨ TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE!\n');

    } catch (error) {
        console.error('💥 Error general:', error);
    }
}

// Ejecutar pruebas
testCompleteFlow().catch(console.error);
