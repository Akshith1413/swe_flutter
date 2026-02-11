import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/translation_service.dart';
import '../services/audio_service.dart';

/// Video Recorder View - Record short videos for diagnosis with a premium UI.
/// Replicated from React's VideoRecorder component.
class VideoRecorderView extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String videoPath) onVideoRecorded;

  const VideoRecorderView({
    super.key,
    required this.onBack,
    required this.onVideoRecorded,
  });

  @override
  State<VideoRecorderView> createState() => _VideoRecorderViewState();
}

class _VideoRecorderViewState extends State<VideoRecorderView> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRecording = false;
  
  // HUD States
  int _recordingTime = 0;
  Timer? _timer;
  static const int maxDuration = 60; // 60 seconds max

  // Post-recording
  XFile? _recordedVideo;
  VideoPlayerController? _videoController;
  bool _isPreviewMode = false;

  // Pulsing Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_pulseController);

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _timer?.cancel();
    _disposeController();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) return;

      final controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: true,
      );

      _controller = controller;
      await controller.initialize();
      
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      // Stop recording
      try {
        final video = await _controller!.stopVideoRecording();
        _timer?.cancel();
        _initializeVideoPlayer(video);
        setState(() {
          _isRecording = false;
          _recordedVideo = video;
          _isPreviewMode = true;
        });
        audioService.playSuccess();
      } catch (e) {
        debugPrint('Error stopping recording: $e');
      }
    } else {
      // Start recording
      try {
        await _controller!.startVideoRecording();
        audioService.playClick();
        setState(() {
          _isRecording = true;
          _recordingTime = 0;
        });
        
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          setState(() {
            _recordingTime++;
          });
          if (_recordingTime >= maxDuration) {
            _toggleRecording();
          }
        });
      } catch (e) {
        debugPrint('Error starting recording: $e');
      }
    }
  }

  Future<void> _initializeVideoPlayer(XFile video) async {
    _videoController?.dispose();
    if (kIsWeb) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(video.path));
    } else {
      _videoController = VideoPlayerController.file(File(video.path));
    }

    await _videoController!.initialize();
    await _videoController!.setLooping(true);
    await _videoController!.play();
    if (mounted) setState(() {});
  }

  void _retakeVideo() {
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _isPreviewMode = false;
      _recordedVideo = null;
      _recordingTime = 0;
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera / Preview Feed
          if (_isPreviewMode && _videoController != null && _videoController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          else if (_isInitialized && _controller != null)
            _buildCameraPreview()
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 2. Header
          _buildHeader(),

          // 3. Recording Timer Overlay (Simulating HUD)
          if (_isRecording) _buildRecordingHud(),

          // 4. Progress Bar
          if (_isRecording) _buildProgressBar(),

          // 5. Controls
          _buildBottomControls(),

          // 6. Max Duration Info
          if (!_isPreviewMode) _buildMaxDurationInfo(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Center(
      child: Transform.scale(
        scale: scale,
        child: CameraPreview(_controller!),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
              onPressed: () {
                if (_isRecording) _toggleRecording();
                widget.onBack();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.t('videoView.title'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (_isRecording)
              Row(
                children: [
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatTime(_recordingTime)} / ${_formatTime(maxDuration)}',
                    style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingHud() {
    return Positioned(
      bottom: 140,
      left: 0, right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radio_button_checked, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Text(_formatTime(_recordingTime), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 4,
        color: Colors.grey[800],
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(seconds: 1),
            width: MediaQuery.of(context).size.width * (_recordingTime / maxDuration),
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
        ),
        child: Center(
          child: _isPreviewMode ? _buildPreviewActions() : _buildShutterButton(),
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _isRecording ? Colors.red : Colors.white, width: 4),
          color: _isRecording ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        ),
        child: Center(
          child: _isRecording
              ? Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)))
              : Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
        ),
      ),
    );
  }

  Widget _buildPreviewActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _retakeVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gray700,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.t('videoView.retake'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () => widget.onVideoRecorded(_recordedVideo!.path),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.nature600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.t('videoView.save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildMaxDurationInfo() {
    return Positioned(
      bottom: 10, left: 0, right: 0,
      child: Center(
        child: Text(
          context.t('videoView.maxDuration'),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ),
    );
  }
}
