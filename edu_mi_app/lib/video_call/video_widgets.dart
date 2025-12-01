import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'video_call_controller.dart';
import 'screen_sharing_windows.dart';

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
        AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: widget.controller.engine,
            connection: RtcConnection(channelId: widget.controller.channelName),
            canvas: VideoCanvas(uid: uid),
          ),
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
