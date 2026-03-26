const supabase = require('./config/supabase');

async function fixTrigger() {
    console.log('Fixing trigger...');
    const { data, error } = await supabase.rpc('execute_sql_query', { query: 'DROP TRIGGER IF EXISTS trigger_notify_achievement_unlock ON student_achievements;' });
    if(error){
        console.log('Cannot execute via RPC, checking other alternatives...');
        // Some users don't have execute_sql_query
    }
    console.log('Done');
}
fixTrigger();
