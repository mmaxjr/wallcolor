import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/camera_session_provider.dart';
import 'mask_paint_overlay.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = ref.read(cameraSessionProvider.notifier);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      session.pause();
    } else if (state == AppLifecycleState.resumed) {
      session.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(cameraSessionProvider);
    final controller = ref.read(cameraSessionProvider.notifier);
    return Scaffold(
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
                        onPressed: controller.toggleDebugMask,
                        icon: Icon(
                          session.debugMask
                              ? Icons.layers
                              : Icons.layers_outlined,
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
                      child: _cameraContent(session, controller),
                    ),
                  ),
                ),
                _palette(context, session, controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraContent(
    CameraSessionState session,
    CameraSessionController actions,
  ) {
    if (session.cameraLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (session.cameraError != null) {
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
                Text(session.cameraError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: actions.initializeCamera,
                  child: const Text('Tentar novamente'),
                ),
                if (session.cameraError!.contains('configurações'))
                  TextButton(
                    onPressed: actions.openCameraSettings,
                    child: const Text('Abrir configurações'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final camera = session.camera;
    if (camera == null || !camera.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF303A33));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(camera),
        if (session.wallMask != null)
          Positioned.fill(
            child: MaskPaintOverlay(
              mask: session.wallMask!,
              paintColor: session.selectedPaintColor,
              debugMask: session.debugMask,
            ),
          ),
        Positioned(
          left: 14,
          top: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                session.modelError ??
                    (session.wallMask == null
                        ? (session.modelLoaded
                              ? 'Procurando paredes…'
                              : 'Carregando modelo…')
                        : 'Máscara atualizada'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _palette(
    BuildContext context,
    CameraSessionState session,
    CameraSessionController actions,
  ) => Container(
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
          children: List.generate(session.palette.length, (index) {
            final selected = index == session.selectedColor;
            return GestureDetector(
              onTap: () => actions.selectColor(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 46 : 40,
                height: selected ? 46 : 40,
                decoration: BoxDecoration(
                  color: session.palette[index].color,
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
        Text(
          '${session.palette[session.selectedColor].name}  •  ${session.modelLoaded ? 'cor aplicada à parede detectada' : 'aguardando modelo TFLite'}',
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    ),
  );
}
