const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
const logger = require('../utils/logger'); // Importar logger interno

// Validar credenciales al inicio
const appId = process.env.AGORA_APP_ID;
const appCertificate = process.env.AGORA_APP_CERTIFICATE;

if (!appId || !appCertificate) {
    logger.error('FATAL: Las variables AGORA_APP_ID y AGORA_APP_CERTIFICATE no están configuradas.');
    // No lanzar error aquí para no chrashear todo el servidor al cargar, 
    // pero fallará al intentar generar token.
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
    if (!appId || !appCertificate) {
        throw new Error('Credenciales de Agora no configuradas');
    }

    if (!channelName) {
        throw new Error('El nombre del canal es requerido');
    }

    try {
        // Convertir el rol a RtcRole
        const agoraRole = role === 'publisher'
            ? RtcRole.PUBLISHER
            : RtcRole.SUBSCRIBER;

        // Tiempo de expiración (timestamp actual + tiempo de expiración)
        // CAPPING: Agora tokens suffer integer overflow if expiration is too far.
        // We cap to 24 hours (86400 seconds).
        const safeExpirationTime = Math.min(expirationTime, 86400);
        const currentTimestamp = Math.floor(Date.now() / 1000);
        const privilegeExpiredTs = currentTimestamp + safeExpirationTime;

        // Generar el token
        const token = RtcTokenBuilder.buildTokenWithUid(
            appId,
            appCertificate,
            channelName,
            uid,
            agoraRole,
            privilegeExpiredTs
        );

        // Debug solo en desarrollo para no leakear tokens en prod
        if (process.env.NODE_ENV === 'development') {
            logger.debug(`Token generado para ${channelName} (Role: ${role}, Exp: ${expirationTime}s)`);
        }

        return token;
    } catch (error) {
        logger.error('Error generando Agora Token:', error);
        throw new Error('Error interno generando token de video');
    }
}

/**
 * Genera tokens para múltiples participantes
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
