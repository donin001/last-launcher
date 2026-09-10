import 'dart:convert';

class AppInfo {
  const AppInfo({
    required this.packageName,
    required this.label,
    this.isWorkApp = false,
  });

  final String packageName;
  final String label;
  final bool isWorkApp;
}

class PinnedApp {
  const PinnedApp({
    required this.packageName,
    required this.label,
    this.isWorkApp = false,
  });

  factory PinnedApp.fromJson(Map<String, dynamic> json) {
    return PinnedApp(
      packageName: json['packageName'] as String,
      label: json['label'] as String,
      isWorkApp: json['isWorkApp'] as bool? ?? false,
    );
  }

  final String packageName;
  final String label;
  final bool isWorkApp;

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'label': label,
      if (isWorkApp) 'isWorkApp': true,
    };
  }

  static List<PinnedApp> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => PinnedApp.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<PinnedApp> apps) {
    return jsonEncode(apps.map((a) => a.toJson()).toList());
  }
}

class AppFolder {
  const AppFolder({
    required this.id,
    required this.name,
    required this.apps,
  });

  factory AppFolder.fromJson(Map<String, dynamic> json) {
    return AppFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      apps: (json['apps'] as List<dynamic>)
          .map((e) => PinnedApp.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final List<PinnedApp> apps;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'apps': apps.map((a) => a.toJson()).toList(),
    };
  }

  AppFolder copyWith({String? name, List<PinnedApp>? apps}) {
    return AppFolder(
      id: id,
      name: name ?? this.name,
      apps: apps ?? this.apps,
    );
  }

  static List<AppFolder> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => AppFolder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String encodeList(List<AppFolder> folders) {
    return jsonEncode(folders.map((f) => f.toJson()).toList());
  }
}
