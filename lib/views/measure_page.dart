import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:collection/collection.dart';

class MeasurePage extends StatefulWidget {
  @override
  _MeasurePageState createState() => _MeasurePageState();
}

class _MeasurePageState extends State<MeasurePage> {
  late ARKitController arkitController;
  vector.Vector3? firstPosition;
  vector.Vector3? secondPosition;
  String? firstNodeName;
  String? secondNodeName;
  String? lineNodeName;
  String? textNodeName;
  String? selectedNodeName;
  vector.Vector3? selectedNodePosition;
  double currentScale = 1.0; // Initial scale

  @override
  void dispose() {
    arkitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Measure Sample'),
        ),
        body: GestureDetector(
          onScaleUpdate: (details) {
            _handleZoom(details.scale);
          },
          child: Stack(
            children: [
              ARKitSceneView(
                enableTapRecognizer: true,
                onARKitViewCreated: onARKitViewCreated,
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: _clearPoints,
                  child: Icon(Icons.clear),
                ),
              ),
            ],
          ),
        ),
      );

  void onARKitViewCreated(ARKitController arkitController) {
    this.arkitController = arkitController;
    this.arkitController.onARTap = (ar) {
      final point = ar.firstWhereOrNull(
        (o) => o.type == ARKitHitTestResultType.featurePoint,
      );
      if (point != null) {
        _handleTap(point);
      }
    };
  }

  void _handleTap(ARKitTestResult point) {
    final position = vector.Vector3(
      point.worldTransform.getColumn(3).x,
      point.worldTransform.getColumn(3).y,
      point.worldTransform.getColumn(3).z,
    );

    if (selectedNodeName != null) {
      _moveNode(selectedNodeName!, position);
      _updateNodeColor(selectedNodeName!, Colors.blue);
      selectedNodeName = null;
      selectedNodePosition = null;
    } else if (firstPosition == null) {
      _addNode(position, isFirst: true);
    } else if (secondPosition == null) {
      _addNode(position, isFirst: false);
    } else {
      // Check if user tapped on an existing node
      _checkNodeSelection(position);
    }
  }

  void _addNode(vector.Vector3 position, {required bool isFirst}) {
    final material = ARKitMaterial(
      lightingModelName: ARKitLightingModel.constant,
      diffuse: ARKitMaterialProperty.color(Colors.blue),
    );
    final sphere = ARKitSphere(
      radius: 0.003,
      materials: [material],
    );

    final nodeName = _generateNodeName();
    final node = ARKitNode(
      geometry: sphere,
      position: position,
      name: nodeName,
      scale: vector.Vector3(currentScale, currentScale, currentScale),
    );
    arkitController.add(node);

    if (isFirst) {
      firstPosition = position;
      firstNodeName = nodeName;
    } else {
      secondPosition = position;
      secondNodeName = nodeName;
      _drawLineAndMeasure();
    }
  }

  void _checkNodeSelection(vector.Vector3 tapPosition) {
    if (firstPosition != null && _isNear(tapPosition, firstPosition!)) {
      selectedNodeName = firstNodeName;
      selectedNodePosition = firstPosition;
      _updateNodeColor(firstNodeName!, Colors.orange);
    } else if (secondPosition != null &&
        _isNear(tapPosition, secondPosition!)) {
      selectedNodeName = secondNodeName;
      selectedNodePosition = secondPosition;
      _updateNodeColor(secondNodeName!, Colors.orange);
    }
  }

  bool _isNear(vector.Vector3 tapPosition, vector.Vector3 nodePosition) {
    const double threshold = 0.02;
    return (tapPosition - nodePosition).length <= threshold;
  }

  void _moveNode(String nodeName, vector.Vector3 newPosition) {
    if (selectedNodePosition == null) return;

    // Remove the node
    arkitController.remove(nodeName);

    // Create a new node with the updated position
    final material = ARKitMaterial(
      lightingModelName: ARKitLightingModel.constant,
      diffuse: ARKitMaterialProperty.color(Colors.blue),
    );
    final sphere = ARKitSphere(
      radius: 0.003,
      materials: [material],
    );
    final node = ARKitNode(
      geometry: sphere,
      position: newPosition,
      name: nodeName,
      scale: vector.Vector3(currentScale, currentScale, currentScale),
    );
    arkitController.add(node);

    if (nodeName == firstNodeName) {
      firstPosition = newPosition;
    } else if (nodeName == secondNodeName) {
      secondPosition = newPosition;
    }

    _drawLineAndMeasure();
  }

  void _updateNodeColor(String nodeName, Color color) {
    final currentPosition =
        (nodeName == firstNodeName) ? firstPosition : secondPosition;
    if (currentPosition == null) return;

    // Remove the node
    arkitController.remove(nodeName);

    // Create a new node with the updated color
    final material = ARKitMaterial(
      lightingModelName: ARKitLightingModel.constant,
      diffuse: ARKitMaterialProperty.color(color),
    );
    final sphere = ARKitSphere(
      radius: 0.003,
      materials: [material],
    );
    final node = ARKitNode(
      geometry: sphere,
      position: currentPosition,
      name: nodeName,
      scale: vector.Vector3(currentScale, currentScale, currentScale),
    );
    arkitController.add(node);
  }

  void _drawLineAndMeasure() {
    if (firstPosition != null && secondPosition != null) {
      if (lineNodeName != null) arkitController.remove(lineNodeName!);
      if (textNodeName != null) arkitController.remove(textNodeName!);

      // Draw the line between the first and second positions
      final line = ARKitLine(
        fromVector: firstPosition!,
        toVector: secondPosition!,
      );
      lineNodeName = _generateNodeName();
      final lineNode = ARKitNode(
        geometry: line,
        name: lineNodeName,
        scale: vector.Vector3(currentScale, currentScale, currentScale),
      );
      arkitController.add(lineNode);

      // Calculate the distance and draw the text
      final distance =
          _calculateDistanceBetweenPoints(firstPosition!, secondPosition!);
      final midPoint = _getMiddleVector(firstPosition!, secondPosition!);
      _drawText(distance, midPoint);
    }
  }

  String _calculateDistanceBetweenPoints(vector.Vector3 A, vector.Vector3 B) {
    final length = A.distanceTo(B);
    return '${(length * 100).toStringAsFixed(2)} cm';
  }

  vector.Vector3 _getMiddleVector(vector.Vector3 A, vector.Vector3 B) {
    return vector.Vector3((A.x + B.x) / 2, (A.y + B.y) / 2, (A.z + B.z) / 2);
  }

  void _drawText(String text, vector.Vector3 point) {
    final textGeometry = ARKitText(
      text: text,
      extrusionDepth: 1,
      materials: [
        ARKitMaterial(
          diffuse: ARKitMaterialProperty.color(Colors.red),
        ),
      ],
    );
    const scale = 0.001;
    final vectorScale = vector.Vector3(scale, scale, scale);
    textNodeName = _generateNodeName();
    final node = ARKitNode(
      geometry: textGeometry,
      position: point,
      scale: vectorScale,
      name: textNodeName,
    );
    arkitController.add(node);
  }

  void _clearPoints() {
    if (firstNodeName != null) arkitController.remove(firstNodeName!);
    if (secondNodeName != null) arkitController.remove(secondNodeName!);
    if (lineNodeName != null) arkitController.remove(lineNodeName!);
    if (textNodeName != null) arkitController.remove(textNodeName!);
    firstPosition = null;
    secondPosition = null;
    firstNodeName = null;
    secondNodeName = null;
    lineNodeName = null;
    textNodeName = null;
    selectedNodeName = null;
    selectedNodePosition = null;
  }

  String _generateNodeName() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  void _handleZoom(double scale) {
    setState(() {
      currentScale =
          scale.clamp(0.5, 2.0); // Clamping scale between 0.5 and 2.0
    });

    // Update the scale of all nodes
    if (firstNodeName != null) {
      arkitController.remove(firstNodeName!);
      _addNode(firstPosition!, isFirst: true);
    }
    if (secondNodeName != null) {
      arkitController.remove(secondNodeName!);
      _addNode(secondPosition!, isFirst: false);
    }
    if (lineNodeName != null &&
        firstPosition != null &&
        secondPosition != null) {
      arkitController.remove(lineNodeName!);
      _drawLineAndMeasure();
    }
    if (textNodeName != null) {
      arkitController.remove(textNodeName!);
      if (firstPosition != null && secondPosition != null) {
        final midPoint = _getMiddleVector(firstPosition!, secondPosition!);
        final distance =
            _calculateDistanceBetweenPoints(firstPosition!, secondPosition!);
        _drawText(distance, midPoint);
      }
    }
  }
}
