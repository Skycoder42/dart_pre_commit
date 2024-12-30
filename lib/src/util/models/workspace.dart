import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

@freezed
@internal
sealed class WorkspacePackage with _$WorkspacePackage {
  const factory WorkspacePackage({
    required String name,
    required String path,
  }) = _WorkspacePackage;

  factory WorkspacePackage.fromJson(Map<String, dynamic> json) =>
      _$WorkspacePackageFromJson(json);
}

@freezed
@internal
sealed class Workspace with _$Workspace {
  const factory Workspace(List<WorkspacePackage> packages) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}
