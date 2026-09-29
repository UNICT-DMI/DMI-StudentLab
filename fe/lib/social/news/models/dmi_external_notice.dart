class DmiExternalNotice {
  final int id;
  final String title;
  final String content;
  final String? teacher;
  final String originalUrl;
  final String? sourceUrl;
  final String university;
  final String? department;
  final String? course;
  final DateTime publishedOn;

  const DmiExternalNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.teacher,
    required this.originalUrl,
    this.sourceUrl,
    required this.university,
    required this.department,
    required this.course,
    required this.publishedOn,
  });

  factory DmiExternalNotice.fromJson(Map<String, dynamic> json) {
    return DmiExternalNotice(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      teacher: json['teacher'] as String?,
      originalUrl: json['original_url'] as String? ?? '',
      sourceUrl: json['source_url'] as String?,
      university: json['university'] as String? ?? 'Università di Catania',
      department: json['department'] as String?,
      course: json['course'] as String?,
      publishedOn: DateTime.parse(json['published_on'] as String),
    );
  }

  String get sourceLabel => [
    if (department != null && department!.isNotEmpty) department!,
    if (course != null && course!.isNotEmpty) course!,
    university,
  ].join(' · ');
}
