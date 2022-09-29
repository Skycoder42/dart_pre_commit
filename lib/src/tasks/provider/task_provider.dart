// coverage:ignore-file

import 'package:meta/meta.dart';
import 'package:riverpod/riverpod.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart';

import '../../task_base.dart';

// ignore: subtype_of_sealed_class
@sealed
class TaskProvider<State extends TaskBase> extends Provider<State> {
  TaskProvider(
    String name,
    super.create, {
    super.dependencies,
    super.from,
    super.argument,
  }) : super(name: name);

  @override
  String get name => super.name!;

  static const configurable = ConfigurableTaskProviderBuilder();
}

typedef ArgFromJson<Arg> = Arg Function(Map<String, dynamic> json);

// ignore: subtype_of_sealed_class
class ConfigurableTaskProviderFamily<State extends TaskBase, Arg>
    extends ProviderFamily<State, Arg> {
  final ArgFromJson<Arg> fromJson;

  ConfigurableTaskProviderFamily(
    String name,
    this.fromJson,
    super.create, {
    super.dependencies,
  }) : super(name: name);

  @override
  String get name => super.name!;
}

// ignore: subtype_of_sealed_class
@sealed
class ConfigurableTaskProviderBuilder {
  const ConfigurableTaskProviderBuilder();

  ConfigurableTaskProviderFamily<State, Arg> call<State extends TaskBase, Arg>(
    String name,
    ArgFromJson<Arg> fromJson,
    FamilyCreate<State, ProviderRef<State>, Arg> create, {
    List<ProviderOrFamily>? dependencies,
  }) =>
      ConfigurableTaskProviderFamily(
        name,
        fromJson,
        create,
        dependencies: dependencies,
      );
}
