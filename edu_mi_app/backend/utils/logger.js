const winston = require('winston');

// Configuración de formatos
const logFormat = winston.format.printf(({ level, message, timestamp, stack }) => {
    return `${timestamp} [${level.toUpperCase()}]: ${stack || message}`;
});

// Crear el logger
const logger = winston.createLogger({
    level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
    format: winston.format.combine(
        winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        winston.format.errors({ stack: true }), // Capturar stack traces
        winston.format.splat(),
        winston.format.json()
    ),
    defaultMeta: { service: 'edumi-backend' },
    transports: [
        // Escribir todos los logs con nivel 'error' o inferior a error.log
        new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
        // Escribir todos los logs a combined.log
        new winston.transports.File({ filename: 'logs/combined.log' }),
    ],
});

// Si no estamos en producción, también loguear a la consola con un formato simple
if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.combine(
            winston.format.colorize(),
            winston.format.timestamp({ format: 'HH:mm:ss' }),
            logFormat
        ),
    }));
}

// Wrapper para morgan (http logger)
logger.stream = {
    write: function (message) {
        // Morgan agrega un salto de línea al final, lo quitamos
        logger.info(message.substring(0, message.lastIndexOf('\n')));
    },
};

module.exports = logger;
