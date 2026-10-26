const maxResumeBytes = 4 * 1024 * 1024;

class ProfileResume {
  const ProfileResume({
    required this.name,
    required this.mimeType,
    required this.size,
  });

  factory ProfileResume.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    return ProfileResume(
      name: name,
      mimeType:
          (json['mimeType'] ??
                  (name.toLowerCase().endsWith('.pdf')
                      ? 'application/pdf'
                      : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'))
              .toString(),
      size: int.tryParse((json['size'] ?? 0).toString()) ?? 0,
    );
  }

  final String name;
  final String mimeType;
  final int size;
}
