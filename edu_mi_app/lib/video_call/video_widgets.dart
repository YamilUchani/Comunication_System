import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:async';
import 'video_call_controller.dart';
import 'screen_sharing_windows.dart';

/// Widget que detecta frames congelados y muestra avatar genérico
class RemoteVideoWithFrozenDetection extends StatefulWidget {
  final int uid;
  final String channelName;
  final RtcEngine rtcEngine;

  const RemoteVideoWithFrozenDetection({
    super.key,
    required this.uid,
    required this.channelName,
    required this.rtcEngine,
  });

  @override
  State<RemoteVideoWithFrozenDetection> createState() =>
      _RemoteVideoWithFrozenDetectionState();
}

class _RemoteVideoWithFrozenDetectionState
    extends State<RemoteVideoWithFrozenDetection> {
  late Timer _frameCheckTimer;
  bool _isFrozen = false;
  DateTime? _lastActivityTime;
  bool _hasReceivedFirstFrame = false;
  late RtcEngineEventHandler _eventHandler;
  String _lastNetworkQuality = ''; // Para evitar logs repetitivos

  @override
  void initState() {
    super.initState();
    _lastActivityTime = null;
    print('🎬 [RemoteVideo ${widget.uid}] initState - Inicializando detector de video congelado');
    
    // Registrar handler para detectar cuando hay movimiento/cambios en video remoto
    _eventHandler = RtcEngineEventHandler(
      // Se dispara cuando el estado del video remoto cambia
      onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
        if (remoteUid == widget.uid) {
          print('📹 [RemoteVideo $remoteUid] onRemoteVideoStateChanged: state=${state.name}, reason=${reason.name}');
          
          // Importar RemoteVideoState para comparaciones
          // Estado: DECODING = actualmente decodificando frames
          if (state.name.contains('Decoding')) {
            print('✅ [RemoteVideo $remoteUid] Video ACTIVO (Decoding frames)');
            _recordActivity('onRemoteVideoStateChanged:Decoding');
          }
          // Estado: FROZEN = video congelado por congestión de red
          else if (state.name.contains('Frozen')) {
            print('❌ [RemoteVideo $remoteUid] Video CONGELADO (Red congestionada)');
            if (!_isFrozen) {
              _isFrozen = true;
              print('🔴 [RemoteVideo $remoteUid] MOSTRANDO AVATAR - Video congelado por red');
              if (mounted) setState(() {});
            }
          }
          // Estado: STOPPED = video parado (usuario offline, muted, etc)
          else if (state.name.contains('Stopped')) {
            print('❌ [RemoteVideo $remoteUid] Video DETENIDO - reason: ${reason.name}');
            if (!_isFrozen) {
              _isFrozen = true;
              print('🔴 [RemoteVideo $remoteUid] MOSTRANDO AVATAR - Video parado/offline');
              if (mounted) setState(() {});
            }
          }
          // STARTING, CONNECTING = transitorio, no congelado aún
          else {
            print('⏳ [RemoteVideo $remoteUid] Estado transitorio: ${state.name}');
          }
        }
      },
      
      // Se dispara cuando cambia el tamaño (frecuentemente con video activo)
      onVideoSizeChanged: (connection, sourceType, uid, width, height, rotation) {
        if (uid == widget.uid && sourceType == VideoSourceType.videoSourceRemote) {
          print('📐 [RemoteVideo $uid] onVideoSizeChanged: ${width}x${height}');
          _recordActivity('onVideoSizeChanged');
        }
      },
      
      // Se dispara regularmente con calidad de red (cada ~1s cuando hay datos)
      // NOTA: Solo registramos cambios significativos para no llenar el log
      onNetworkQuality: (connection, uid, txQuality, rxQuality) {
        if (uid == widget.uid) {
          final qualityString = 'tx=${txQuality.name}, rx=${rxQuality.name}';
          // Solo registrar si cambió la calidad (no repetir el mismo estado)
          if (qualityString != _lastNetworkQuality) {
            _lastNetworkQuality = qualityString;
            print('📊 [RemoteVideo $uid] onNetworkQuality: $qualityString');
          }
          
          // 🚨 Si la red es DESCONOCIDA/PERDIDA, CONGELAR INSTANTÁNEAMENTE
          // No esperar timeout, la conexión se perdió
          final isUnknown = txQuality.name.contains('Unknown') || rxQuality.name.contains('Unknown');
          if (isUnknown) {
            if (!_isFrozen) {
              setState(() {
                _isFrozen = true;
                print('❌ [RemoteVideo $uid] Red desconocida - CONGELANDO INSTANTÁNEAMENTE');
                print('🔴 [RemoteVideo $uid] MOSTRANDO AVATAR - Sin conexión');
              });
            }
          } else {
            // Red está buena/normal, registrar como actividad
            _recordActivity('onNetworkQuality');
            // Si se recuperó, descongelar
            if (_isFrozen) {
              setState(() {
                _isFrozen = false;
                print('✅ [RemoteVideo $uid] Red recuperada (${txQuality.name})');
              });
            }
          }
        }
      },
    );
    
    widget.rtcEngine.registerEventHandler(_eventHandler);
    print('🎬 [RemoteVideo ${widget.uid}] EventHandler registrado');
    
    // Timer para chequear cada 1 segundo si hay actividad
    // (timeout de 2 segundos sin actividad) ⚡ REDUCIDO de 6s a 2s
    _frameCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _lastActivityTime != null) {
        setState(() {
          final now = DateTime.now();
          final secondsSinceLastActivity = now.difference(_lastActivityTime!).inSeconds;
          
          // Si no hay actividad en 2+ segundos, está congelado
          if (secondsSinceLastActivity >= 2) {
            if (!_isFrozen) {
              _isFrozen = true;
              print('❌ [RemoteVideo ${widget.uid}] Video congelado por timeout (${secondsSinceLastActivity}s sin actividad)');
              print('🔴 [RemoteVideo ${widget.uid}] MOSTRANDO AVATAR - Timeout sin frames');
            }
          } else {
            // Hay actividad, video OK
            if (_isFrozen) {
              _isFrozen = false;
              print('✅ [RemoteVideo ${widget.uid}] Video RECUPERADO después de ${secondsSinceLastActivity}s');
            }
          }
        });
      }
    });
    print('🎬 [RemoteVideo ${widget.uid}] Timer de detección iniciado (1s intervals, 2s timeout)');
  }

  void _recordActivity(String source) {
    if (mounted) {
      setState(() {
        // Primer vez que vemos actividad
        if (!_hasReceivedFirstFrame) {
          _hasReceivedFirstFrame = true;
          print('🟢 [RemoteVideo ${widget.uid}] PRIMER FRAME detectado (via $source)');
        }
        
        // Actualizar timestamp de última actividad
        _lastActivityTime = DateTime.now();
        
        // Si estaba congelado, ya no lo está
        if (_isFrozen) {
          _isFrozen = false;
          print('✅ [RemoteVideo ${widget.uid}] VIDEO RECUPERADO - Reanudando stream (via $source)');
        }
      });
    }
  }

  @override
  void dispose() {
    _frameCheckTimer.cancel();
    widget.rtcEngine.unregisterEventHandler(_eventHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFrozen) {
      // Mostrar Avatar genérico cuando el video está congelado
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.teal,
                child: Text(
                  'UID\n${widget.uid}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Usuario sin conexión',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mostrar video normal
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: widget.rtcEngine,
        connection: RtcConnection(channelId: widget.channelName),
        canvas: VideoCanvas(uid: widget.uid),
      ),
    );
  }
}

class VideoWidgetWrapper extends StatefulWidget {
  final int uid;
  final Widget child;
  final bool isScreenShare;
  final Function(int) onDoubleTap;
  final bool isMaximized;

  const VideoWidgetWrapper({
    super.key,
    required this.uid,
    required this.child,
    required this.isScreenShare,
    required this.onDoubleTap,
    required this.isMaximized,
  });

  @override
  State<VideoWidgetWrapper> createState() => _VideoWidgetWrapperState();
}

class _VideoWidgetWrapperState extends State<VideoWidgetWrapper> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => widget.onDoubleTap(widget.uid),
      child: widget.isMaximized
          ? Stack(
              children: [
                widget.child,
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => widget.onDoubleTap(-1),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_fullscreen,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : widget.child,
    );
  }
}

class VideoWidgets extends StatefulWidget {
  final VideoCallController controller;
  final ScreenShareController? screenController;

  const VideoWidgets({
    super.key,
    required this.controller,
    this.screenController,
  });

  @override
  State<VideoWidgets> createState() => _VideoWidgetsState();
}

class _VideoWidgetsState extends State<VideoWidgets> {
  int simulatedUsersCount = 0;
  int? _maximizedUid;

  void _toggleMaximizeView(int uid) {
    setState(() {
      if (_maximizedUid == uid || uid == -1) {
        _maximizedUid = null;
      } else {
        _maximizedUid = uid;
      }
    });
  }

  Widget _buildMaximizedView(Set<int> remoteUids, bool isScreenSharing) {
    Widget? maximizedWidget;

    if (_maximizedUid == -999 && isScreenSharing) {
      // Pantalla local compartida
      maximizedWidget = _buildScreenShareView(true);
    } else if (_maximizedUid == 0) {
      // Video local
      maximizedWidget = _buildLocalVideoView(true);
    } else if (remoteUids.contains(_maximizedUid)) {
      // Aquí verificamos si el remoto está compartiendo pantalla
      if (widget.controller.remoteScreenShareUids.value.contains(
        _maximizedUid,
      )) {
        maximizedWidget = _buildRemoteScreenShareView(_maximizedUid!, true);
      } else {
        maximizedWidget = _buildRemoteVideoView(_maximizedUid!, true);
      }
    } else if (_maximizedUid! < 0) {
      // Usuarios simulados
      maximizedWidget = _buildSimulatedVideoView(_maximizedUid!, true);
    }

    if (maximizedWidget == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _maximizedUid = null;
          });
        }
      });
      return Container();
    }

    return maximizedWidget;
  }

  int _calculateCrossAxisCount(int itemCount) {
    if (itemCount <= 4) return 2;
    if (itemCount <= 9) return 3;
    if (itemCount <= 16) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black.withOpacity(0.7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Usuarios simulados: ',
                style: TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: () {
                  setState(() {
                    if (simulatedUsersCount > 0) {
                      simulatedUsersCount--;
                    }
                  });
                },
              ),
              Text(
                '$simulatedUsersCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  setState(() {
                    simulatedUsersCount++;
                  });
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: ValueListenableBuilder<Set<int>>(
            valueListenable: widget.controller.remoteUids,
            builder: (context, remoteUids, child) {
              return ValueListenableBuilder<bool>(
                valueListenable:
                    widget.screenController?.isSharingNotifier ??
                    ValueNotifier(false),
                builder: (context, isScreenSharing, _) {
                  if (_maximizedUid != null) {
                    return _buildMaximizedView(remoteUids, isScreenSharing);
                  }

                  final allItems = <Widget>[];

                  if (isScreenSharing) {
                    allItems.add(_buildScreenShareView(false));
                  }

                  allItems.add(_buildLocalVideoView(false));

                  for (final uid in remoteUids) {
                    if (widget.controller.remoteScreenShareUids.value.contains(
                      uid,
                    )) {
                      allItems.add(_buildRemoteScreenShareView(uid, false));
                    } else {
                      allItems.add(_buildRemoteVideoView(uid, false));
                    }
                  }

                  for (int i = 1; i <= simulatedUsersCount; i++) {
                    allItems.add(_buildSimulatedVideoView(-i, false));
                  }

                  if (allItems.isEmpty) {
                    return const Center(
                      child: Text(
                        'Esperando a otros participantes...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    );
                  }

                  final crossAxisCount = _calculateCrossAxisCount(
                    allItems.length,
                  );

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 16 / 9,
                    ),
                    padding: const EdgeInsets.all(4),
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[600]!,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: allItems[index],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScreenShareView(bool isMaximized) {
    final screenShareWidget = Stack(
      children: [
        AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: widget.controller.engine,
            canvas: const VideoCanvas(
              uid: 0,
              sourceType: VideoSourceType.videoSourceScreen,
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'PANTALLA',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMaximized ? 14 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );

    return VideoWidgetWrapper(
      uid: -999,
      isScreenShare: true,
      onDoubleTap: _toggleMaximizeView,
      isMaximized: isMaximized,
      child: isMaximized
          ? screenShareWidget
          : AspectRatio(aspectRatio: 16 / 9, child: screenShareWidget),
    );
  }

  Widget _buildSimulatedVideoView(int uid, bool isMaximized) {
    final iconSize = isMaximized ? 60.0 : 30.0;
    final titleFontSize = isMaximized ? 20.0 : 12.0;
    final subtitleFontSize = isMaximized ? 16.0 : 10.0;

    final simulatedWidget = Container(
      color: Colors.grey[900],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: iconSize, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            'Usuario ${uid.abs()}',
            style: TextStyle(color: Colors.white, fontSize: titleFontSize),
          ),
          const SizedBox(height: 4),
          Text(
            'SIMULADO',
            style: TextStyle(
              color: Colors.blue[300],
              fontSize: subtitleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    return VideoWidgetWrapper(
      uid: uid,
      isScreenShare: false,
      onDoubleTap: _toggleMaximizeView,
      isMaximized: isMaximized,
      child: isMaximized
          ? simulatedWidget
          : AspectRatio(aspectRatio: 16 / 9, child: simulatedWidget),
    );
  }

  Widget _buildLocalVideoView(bool isMaximized) {
    final fontSize = isMaximized ? 14.0 : 10.0;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.localUserJoined,
      builder: (context, localUserJoined, child) {
        if (!localUserJoined) {
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: Text(
                'Conectando...',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        }

        final localVideoWidget = Stack(
          children: [
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: widget.controller.engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'TÚ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );

        return VideoWidgetWrapper(
          uid: 0,
          isScreenShare: false,
          onDoubleTap: _toggleMaximizeView,
          isMaximized: isMaximized,
          child: isMaximized
              ? localVideoWidget
              : AspectRatio(aspectRatio: 16 / 9, child: localVideoWidget),
        );
      },
    );
  }

  Widget _buildRemoteScreenShareView(int uid, bool isMaximized) {
    final fontSize = isMaximized ? 14.0 : 10.0;

    final remoteScreenWidget = Stack(
      children: [
        AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: widget.controller.engine,
            connection: RtcConnection(channelId: widget.controller.channelName),
            canvas: VideoCanvas(
              uid: uid,
              sourceType: VideoSourceType.videoSourceScreen, // pantalla remota
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Pantalla UID: $uid',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );

    return VideoWidgetWrapper(
      uid: uid,
      isScreenShare: true,
      onDoubleTap: _toggleMaximizeView,
      isMaximized: isMaximized,
      child: isMaximized
          ? remoteScreenWidget
          : AspectRatio(aspectRatio: 16 / 9, child: remoteScreenWidget),
    );
  }

  Widget _buildRemoteVideoView(int uid, bool isMaximized) {
    final fontSize = isMaximized ? 14.0 : 10.0;

    final remoteVideoWidget = Stack(
      children: [
        // 🎥 Usar widget con detección de frames congelados
        RemoteVideoWithFrozenDetection(
          uid: uid,
          channelName: widget.controller.channelName,
          rtcEngine: widget.controller.engine,
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'UID: $uid',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );

    return VideoWidgetWrapper(
      uid: uid,
      isScreenShare: false,
      onDoubleTap: _toggleMaximizeView,
      isMaximized: isMaximized,
      child: isMaximized
          ? remoteVideoWidget
          : AspectRatio(aspectRatio: 16 / 9, child: remoteVideoWidget),
    );
  }
}
