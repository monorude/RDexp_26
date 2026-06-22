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
      title: fields[0] as String,
      description: fields[1] as String,
      dueDate: fields[2] as DateTime,
      isCompleted: fields[3] as bool,
      tags: (fields[4] as List?)?.cast<String>() ?? [],
      collegeTime: fields[5] as int,
      repeatInterval: fields[6] as String?,
      repeatEndType: fields[7] as String?,
      isMuted: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, NormalTask obj) {
    writer
      ..writeByte(9) // フィールドの総数
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.dueDate)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.collegeTime)
      ..writeByte(6)
      ..write(obj.repeatInterval)
      ..writeByte(7)
      ..write(obj.repeatEndType) // ✨ ここを正しい記述に直しました
      ..writeByte(8)
      ..write(obj.isMuted);
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
