import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/camera/camera_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  final _cameraService = CameraService();
  CameraController? _controller;
  String? _error;
  bool _loading = true;
  int _selectedColor = 1;
  bool _showMask = false;

  static const _colors = <Color>[
    Color(0xFFE8DFCC),
    Color(0xFFA8B6A0),
    Color(0xFF708A78),
    Color(0xFFC98F72),
    Color(0xFF7589A0),
    Color(0xFFD5C66C),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      setState(() {
        _loading = false;
        _error = permission.isPermanentlyDenied
            ? 'A permissão da câmera está bloqueada. Ative-a nas configurações do Android.'
            : 'A permissão da câmera é necessária para visualizar a parede.';
      });
      return;
    }
    try {
      final controller = await _cameraService.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } on CameraException catch (error) {
      setState(() {
        _loading = false;
        _error =
            'Não foi possível iniciar a câmera: ${error.description ?? error.code}';
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = 'Falha ao abrir a câmera: $error';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && mounted) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF202722)),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.format_paint, size: 25),
                    const SizedBox(width: 10),
                    Text(
                      'WallColor',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Alternar máscara de depuração',
                      onPressed: () => setState(() => _showMask = !_showMask),
                      icon: Icon(
                        _showMask ? Icons.layers : Icons.layers_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: _cameraContent(),
                  ),
                ),
              ),
              _palette(context),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _cameraContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ColoredBox(
        color: const Color(0xFF303A33),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, size: 48),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _initializeCamera,
                  child: const Text('Tentar novamente'),
                ),
                if (_error!.contains('configurações'))
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('Abrir configurações'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        if (_showMask) ColoredBox(color: Colors.green.withValues(alpha: 0.28)),
        Positioned(
          left: 14,
          top: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Modelo ADE20K não configurado',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _palette(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
    decoration: const BoxDecoration(
      color: Color(0xFF171D19),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Escolha uma cor', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_colors.length, (index) {
            final selected = index == _selectedColor;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 46 : 40,
                height: selected ? 46 : 40,
                decoration: BoxDecoration(
                  color: _colors[index],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 3 : 1,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        const Text(
          'A seleção de cor será aplicada após configurar o modelo.',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    ),
  );
}
