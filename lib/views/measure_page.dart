import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:collection/collection.dart';

class MeasurePage extends StatefulWidget {
  const MeasurePage({super.key});

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
  bool isCm = true; // To track the measurement unit
  bool isMeasurementValid = false; // To track the validation state
  double? currentMeasurement; // To store the current measurement value

  @override
  void dispose() {
    arkitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Measure with ARKit'),
        ),
        body: Stack(
          children: [
            ARKitSceneView(
              enableTapRecognizer: true,
              onARKitViewCreated: onARKitViewCreated,
              enablePinchRecognizer: true,
            ),
            Positioned(
              top: 16,
              right: 16,
              child: ToggleButtons(
                color: Colors.white,
                isSelected: [isCm, !isCm],
                onPressed: (index) {
                  setState(() {
                    isCm = index == 0;
                    _drawLineAndMeasure(); // Update the displayed measurement
                  });
                },
                children: const [Text('cm'), Text('inch')],
              ),
            ),
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: _clearPoints,
                    child: const Icon(Icons.clear),
                  ),
                  const SizedBox(width: 30),
                  FloatingActionButton(
                    onPressed: () {
                      _validateMeasurement();
                    },
                    child: const Icon(Icons.check),
                  ),
                ],
              ),
            ),
          ],
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
      radius: 0.001,
      materials: [material],
    );

    final nodeName = _generateNodeName();
    final node = ARKitNode(
      geometry: sphere,
      position: position,
      name: nodeName,
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
      radius: 0.001,
      materials: [material],
    );
    final node = ARKitNode(
      geometry: sphere,
      position: newPosition,
      name: nodeName,
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
      radius: 0.001,
      materials: [material],
    );
    final node = ARKitNode(
      geometry: sphere,
      position: currentPosition,
      name: nodeName,
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
    final convertedLength = isCm ? length * 100 : length * 39.3701;
    currentMeasurement = convertedLength; // Store the measurement
    return isCm
        ? '${convertedLength.toStringAsFixed(2)} cm'
        : '${convertedLength.toStringAsFixed(2)} inches';
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
    isMeasurementValid = false;
    currentMeasurement = null;
  }

  void _validateMeasurement() {
    if (currentMeasurement == null) {
      return;
    }

    setState(() {
      isMeasurementValid = true;
    });
    // Provide haptic feedback and visual confirmation here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Measurement validated: ${currentMeasurement?.toStringAsFixed(2)} ${isCm ? "cm" : "inches"}'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 750),
      ),
    );
  }

  String _generateNodeName() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
