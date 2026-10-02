class SraapAcademicData {
  final double? overallAttendance;
  final List<SraapSubjectAttendance> subjects;
  final String? cgpa;
  final SraapMentor? mentor;
  final DateTime lastSynced;

  SraapAcademicData({
    this.overallAttendance,
    this.subjects = const [],
    this.cgpa,
    this.mentor,
    required this.lastSynced,
  });

  Map<String, dynamic> toJson() {
    return {
      'overallAttendance': overallAttendance,
      'subjects': subjects.map((x) => x.toJson()).toList(),
      'cgpa': cgpa,
      'mentor': mentor?.toJson(),
      'lastSynced': lastSynced.toIso8601String(),
    };
  }

  factory SraapAcademicData.fromJson(Map<String, dynamic> json) {
    return SraapAcademicData(
      overallAttendance: json['overallAttendance'] as double?,
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((x) => SraapSubjectAttendance.fromJson(x))
              .toList() ??
          [],
      cgpa: json['cgpa'] as String?,
      mentor: json['mentor'] != null ? SraapMentor.fromJson(json['mentor']) : null,
      lastSynced: DateTime.tryParse(json['lastSynced'] ?? '') ?? DateTime.now(),
    );
  }
}

class SraapSubjectAttendance {
  final String subjectName;
  final double attendancePercentage;
  final int? presentCount;
  final int? absentCount;
  final int? totalCount;

  SraapSubjectAttendance({
    required this.subjectName,
    required this.attendancePercentage,
    this.presentCount,
    this.absentCount,
    this.totalCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'subjectName': subjectName,
      'attendancePercentage': attendancePercentage,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'totalCount': totalCount,
    };
  }

  factory SraapSubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SraapSubjectAttendance(
      subjectName: json['subjectName'] ?? 'Unknown Subject',
      attendancePercentage: (json['attendancePercentage'] as num?)?.toDouble() ?? 0.0,
      presentCount: json['presentCount'] as int?,
      absentCount: json['absentCount'] as int?,
      totalCount: json['totalCount'] as int?,
    );
  }
}

class SraapMentor {
  final String name;
  final String? department;

  SraapMentor({
    required this.name,
    this.department,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
    };
  }

  factory SraapMentor.fromJson(Map<String, dynamic> json) {
    return SraapMentor(
      name: json['name'] ?? 'Unknown Mentor',
      department: json['department'] as String?,
    );
  }
}
