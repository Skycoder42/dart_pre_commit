import 'package:freezed_annotation/freezed_annotation.dart';

import 'package_info.dart';

part 'outdated_info.freezed.dart';
part 'outdated_info.g.dart';

@freezed
@internal
class OutdatedInfo with _$OutdatedInfo {
  const factory OutdatedInfo({
    required List<PackageInfo> packages,
  }) = _OutdatedInfo;

  factory OutdatedInfo.fromJson(Map<String, dynamic> json) =>
      _$OutdatedInfoFromJson(json);
}
