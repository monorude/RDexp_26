import 'package:hive/hive.dart';
import 'NormalTask.dart';

class NormalTaskAdapter extends TypeAdapter<NormalTask> {
  @override
  final int typeId = 0;

  @override
  NormalTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NormalTask(
      title: fields[1] as String,
      description: fields[2] as String,
      dueDate: fields[3] as DateTime,
      isCompleted: fields[4] as bool,
      tag: fields[5] as String,
      collegeTime: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, NormalTask obj) {
    writer
      ..writeByte(6) // フィールド数
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.dueDate)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.tag)
      ..writeByte(5)
      ..write(obj.collegeTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
