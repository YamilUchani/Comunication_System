const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const appId = process.env.AGORA_APP_ID;
const appCertificate = process.env.AGORA_APP_CERTIFICATE;

if (!appId || !appCertificate) {
    throw new Error('Las variables AGORA_APP_ID y AGORA_APP_CERTIFICATE son requeridas');
}

/**
 * Genera un token RTC de Agora para un canal específico
 * @param {string} channelName - Nombre del canal
 * @param {number} uid - UID del usuario (0 para auto-asignación)
 * @param {string} role - Rol del usuario ('publisher' o 'subscriber')
 * @param {number} expirationTime - Tiempo de expiración en segundos
 * @returns {string} Token de Agora
 */
function generateRtcToken(channelName, uid = 0, role = 'publisher', expirationTime = 3600) {
    if (!channelName) {
        throw new Error('El nombre del canal es requerido');
    }

    // Convertir el rol a RtcRole
    const agoraRole = role === 'publisher'
        ? RtcRole.PUBLISHER
        : RtcRole.SUBSCRIBER;

    // Tiempo de expiración (timestamp actual + tiempo de expiración)
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTime;

    // Generar el token
    const token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channelName,
        uid,
        agoraRole,
        privilegeExpiredTs
    );

    return token;
}

/**
 * Genera tokens para múltiples participantes
 * @param {string} channelName - Nombre del canal
 * @param {Array} participants - Array de objetos con {uid, role}
 * @param {number} expirationTime - Tiempo de expiración en segundos
 * @returns {Array} Array de objetos con {uid, token}
 */
function generateTokensForParticipants(channelName, participants, expirationTime = 3600) {
    return participants.map(participant => ({
        uid: participant.uid,
        token: generateRtcToken(
            channelName,
            participant.uid,
            participant.role || 'publisher',
            expirationTime
        )
    }));
}

/**
 * Valida si un nombre de canal es válido
 * @param {string} channelName - Nombre del canal
 * @returns {boolean} true si es válido
 */
function isValidChannelName(channelName) {
    // El nombre del canal debe tener entre 1 y 64 caracteres
    // Puede contener letras, números, guiones y guiones bajos
    const channelNameRegex = /^[a-zA-Z0-9_-]{1,64}$/;
    return channelNameRegex.test(channelName);
}

module.exports = {
    generateRtcToken,
    generateTokensForParticipants,
    isValidChannelName
};
