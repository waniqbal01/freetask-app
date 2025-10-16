import 'package:equatable/equatable.dart';

class MessageAttachment extends Equatable {
  const MessageAttachment({
    required this.url,
    required this.name,
    required this.mimeType,
    required this.size,
    this.localPath,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      url: json['url']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      size: json['size'] is int
          ? json['size'] as int
          : int.tryParse(json['size']?.toString() ?? '0') ?? 0,
      localPath: json['localPath']?.toString(),
    );
  }

  factory MessageAttachment.local({
    required String path,
    required String name,
    required String mimeType,
    int size = 0,
  }) {
    return MessageAttachment(
      url: '',
      name: name,
      mimeType: mimeType,
      size: size,
      localPath: path,
    );
  }

  final String url;
  final String name;
  final String mimeType;
  final int size;
  final String? localPath;

  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  bool get isVideo => mimeType.toLowerCase().startsWith('video/');

  bool get isFile => !isImage && !isVideo;

  MessageAttachment copyWith({
    String? url,
    String? name,
    String? mimeType,
    int? size,
    String? localPath,
  }) {
    return MessageAttachment(
      url: url ?? this.url,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      localPath: localPath ?? this.localPath,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'name': name,
      'mimeType': mimeType,
      'size': size,
      if (localPath != null) 'localPath': localPath,
    };
  }

  @override
  List<Object?> get props => [url, name, mimeType, size, localPath];
}
