import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';


class YoloDetectionService {
  Interpreter? _interpreter;
  List<String> _labels = ['license_plate'];
  
  static const String MODEL_FILE = 'thai_plate_yolov8.tflite';
  static const int INPUT_SIZE = 640;
  static const double CONFIDENCE_THRESHOLD = 0.5;
  static const double IOU_THRESHOLD = 0.5;
  
  // Singleton pattern
  static final YoloDetectionService _instance = YoloDetectionService._internal();
  factory YoloDetectionService() => _instance;
  YoloDetectionService._internal();
  
  /// Initialize YOLO model
  Future<void> initialize() async {
    try {
      // Load model from assets
      _interpreter = await Interpreter.fromAsset('assets/models/$MODEL_FILE');
      print('✅ YOLO model loaded successfully');
      
      // Get input/output shapes
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Input shape: $inputShape');
      print('Output shape: $outputShape');
      
    } catch (e) {
      print('❌ Error initializing YOLO: $e');
      throw Exception('Failed to initialize YOLO model');
    }
  }
  
  /// Detect license plates in image
  Future<List<Detection>> detectLicensePlates(XFile imageFile) async {
    if (_interpreter == null) {
      throw Exception('Model not initialized. Call initialize() first.');
    }
    
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) throw Exception('Failed to decode image');
      
      // Store original dimensions
      final originalWidth = image.width;
      final originalHeight = image.height;
      
      // Resize to model input size
      img.Image resized = img.copyResize(image, width: INPUT_SIZE, height: INPUT_SIZE);
      
      // Convert to input tensor
      var input = _imageToByteListFloat32(resized);
      
      // Prepare output
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      var output = List.generate(
        outputShape[0],
        (i) => List.generate(
          outputShape[1],
          (j) => List.filled(outputShape[2], 0.0),
        ),
      );
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Parse detections
      List<Detection> detections = _parseYoloOutput(
        output[0],
        originalWidth,
        originalHeight,
      );
      
      // Apply NMS
      detections = _applyNMS(detections);
      
      print('🎯 Found ${detections.length} license plates');
      return detections;
      
    } catch (e) {
      print('❌ Error during detection: $e');
      return [];
    }
  }
  
  /// Convert image to byte list for model input
  Uint8List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * INPUT_SIZE * INPUT_SIZE * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    
    int pixelIndex = 0;
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        var pixel = image.getPixel(x, y);
        
        // RGB normalization [0, 1]
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    
    return convertedBytes.buffer.asUint8List();
  }
  
  /// Parse YOLO output format
  List<Detection> _parseYoloOutput(
    List<List<double>> output,
    int originalWidth,
    int originalHeight,
  ) {
    List<Detection> detections = [];
    
    // YOLOv8 output format: [8400, 6] where 6 = [x, y, w, h, confidence, class_score]
    for (int i = 0; i < output.length; i++) {
      double confidence = output[i][4]; // Object confidence
      
      if (confidence > CONFIDENCE_THRESHOLD) {
        // Get bounding box (already in pixel coordinates from YOLOv8)
        double x = output[i][0];
        double y = output[i][1];
        double w = output[i][2];
        double h = output[i][3];
        
        // Convert center coordinates to top-left
        double xMin = x - w / 2;
        double yMin = y - h / 2;
        
        // Scale to original image size
        double scaleX = originalWidth / INPUT_SIZE;
        double scaleY = originalHeight / INPUT_SIZE;
        
        xMin *= scaleX;
        yMin *= scaleY;
        w *= scaleX;
        h *= scaleY;
        
        // Clamp to image bounds
        xMin = xMin.clamp(0, originalWidth.toDouble());
        yMin = yMin.clamp(0, originalHeight.toDouble());
        w = w.clamp(0, originalWidth - xMin);
        h = h.clamp(0, originalHeight - yMin);
        
        detections.add(Detection(
          boundingBox: Rect.fromLTWH(xMin, yMin, w, h),
          confidence: confidence,
          className: _labels[0],
          classIndex: 0,
        ));
      }
    }
    
    return detections;
  }
  
  /// Apply Non-Maximum Suppression
  List<Detection> _applyNMS(List<Detection> detections) {
    if (detections.isEmpty) return detections;
    
    // Sort by confidence descending
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    List<Detection> kept = [];
    List<bool> suppressed = List.filled(detections.length, false);
    
    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      kept.add(detections[i]);
      
      // Suppress overlapping detections
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        double iou = _calculateIOU(
          detections[i].boundingBox,
          detections[j].boundingBox,
        );
        
        if (iou > IOU_THRESHOLD) {
          suppressed[j] = true;
        }
      }
    }
    
    return kept;
  }
  
  /// Calculate Intersection over Union
  double _calculateIOU(Rect box1, Rect box2) {
    // Calculate intersection
    double x1 = max(box1.left, box2.left);
    double y1 = max(box1.top, box2.top);
    double x2 = min(box1.right, box2.right);
    double y2 = min(box1.bottom, box2.bottom);
    
    if (x2 < x1 || y2 < y1) return 0.0;
    
    double intersection = (x2 - x1) * (y2 - y1);
    
    // Calculate union
    double area1 = box1.width * box1.height;
    double area2 = box2.width * box2.height;
    double union = area1 + area2 - intersection;
    
    return intersection / union;
  }
  
  /// Crop detected license plate region
  Future<File?> cropDetection(XFile imageFile, Detection detection) async {
    try {
      // Read original image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;
      
      // Add padding around detection
      int padding = 15;
      int x = (detection.boundingBox.left - padding).round().clamp(0, image.width);
      int y = (detection.boundingBox.top - padding).round().clamp(0, image.height);
      int w = (detection.boundingBox.width + 2 * padding).round();
      int h = (detection.boundingBox.height + 2 * padding).round();
      
      // Ensure bounds
      w = w.clamp(0, image.width - x);
      h = h.clamp(0, image.height - y);
      
      // Crop image
      img.Image cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
      
      // Enhance for OCR
      cropped = img.adjustColor(cropped, contrast: 1.3);
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/cropped_plate_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );
      
      await tempFile.writeAsBytes(img.encodeJpg(cropped, quality: 95));
      
      return tempFile;
      
    } catch (e) {
      print('❌ Error cropping: $e');
      return null;
    }
  }
  
  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Detection result class
class Detection {
  final Rect boundingBox;
  final double confidence;
  final String className;
  final int classIndex;
  
  Detection({
    required this.boundingBox,
    required this.confidence,
    required this.className,
    required this.classIndex,
  });
  
  @override
  String toString() {
    return 'Detection(class: $className, confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
           'box: [${boundingBox.left.toInt()}, ${boundingBox.top.toInt()}, '
           '${boundingBox.width.toInt()}, ${boundingBox.height.toInt()}])';
  }
}