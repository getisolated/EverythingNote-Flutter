import 'package:flutter/foundation.dart';

@immutable
class Project {
  final String id;
  final String name;

  const Project({required this.id, required this.name});
}
