import 'package:equatable/equatable.dart';

abstract class ParentClass extends Equatable {
  final String? parentField;

  const ParentClass({this.parentField});

  @override
  List<Object?> get props => [parentField];
}
