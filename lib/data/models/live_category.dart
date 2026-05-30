import 'package:equatable/equatable.dart';

class LiveCategory extends Equatable {
  final String categoryId;
  final String categoryName;
  final int parentId;

  const LiveCategory({
    required this.categoryId,
    required this.categoryName,
    required this.parentId,
  });

  factory LiveCategory.fromJson(Map<String, dynamic> j) => LiveCategory(
        categoryId: j['category_id']?.toString() ?? '',
        categoryName: j['category_name']?.toString() ?? '',
        parentId: j['parent_id'] is int
            ? j['parent_id'] as int
            : int.tryParse(j['parent_id']?.toString() ?? '0') ?? 0,
      );

  @override
  List<Object?> get props => [categoryId];
}
