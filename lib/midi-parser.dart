import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

MidiMessage parseMidiMessage(List<int> data) {
  int status = data[0];
  assert(status & 0x80 > 0, 'no STATUS byte');
  if (status & 0xf0 == 0x90) {
    return NoteOnMessage(
      channel: status & 0x0f,
      note: data[1],
      velocity: data[2],
    );
  }
  if (status & 0xf0 == 0x80) {
    return NoteOffMessage(
      channel: status & 0x0f,
      note: data[1],
      velocity: data[2],
    );
  }
  if (status & 0xf0 == 0xc0) {
    return PCMessage(
      channel: status & 0x0f,
      program: data[1],
    );
  }
  if (status & 0xf0 == 0xb0) {
    return CCMessage(
      channel: status & 0x0f,
      controller: data[0],
      value: data[1],
    );
  }
  throw FormatException("Unknown status byte 0x${status.toRadixString(16)}");
}

String prettyPrintMidiMessage(MidiMessage message) {
  if (message is NoteOnMessage) {
    return "(Note ${message.note} on channel ${message.channel} with velocity ${message.velocity} on)";
  }
  if (message is NoteOffMessage) {
    return "(Note ${message.note} on channel ${message.channel} with velocity ${message.velocity} off)";
  }
  if (message is PCMessage) {
    return "(Instrument ${message.program} on channel ${message.channel} selected)";
  }
  if (message is CCMessage) {
    return "(Controller ${message.controller} on channel ${message.channel} set to value ${message.value})";
  }
  return message.data.map((e) => e.toRadixString(16)).toString();
}
