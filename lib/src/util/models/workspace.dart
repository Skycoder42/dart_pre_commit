import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

@freezed
@internal
sealed class WorkspacePackage with _$WorkspacePackage {
  const factory({required String name, required String path}) =
      _WorkspacePackage;

  factory fromJson(Map<String, dynamic> json) =>
      _$WorkspacePackageFromJson(json);
}

@freezed
@internal
sealed class Workspace with _$Workspace {
  const factory(List<WorkspacePackage> packages) = _Workspace;

  factory fromJson(Map<String, dynamic> json) => _$WorkspaceFromJson(json);
}
