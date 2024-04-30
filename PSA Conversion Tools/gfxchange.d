import std.stdio, std.file, std.algorithm, std.array, std.conv, std.string, std.bitmanip, std.typecons;

alias Opcode = Tuple!(ubyte[], "bytes", uint, "argOffset");

auto opcodes = [
  //graphic effects
  Opcode(Bytes!"11 00 10 00", 0),
  Opcode(Bytes!"11 01 0A 00", 0),
  Opcode(Bytes!"11 02 0A 00", 0),
  Opcode(Bytes!"11 15 03 00", 0),
  Opcode(Bytes!"11 1A 10 00", 0),
  Opcode(Bytes!"11 1B 10 00", 0),
  Opcode(Bytes!"11 1C 10 00", 0),
  Opcode(Bytes!"0E 0B 02 00", 0),

  //sword glows
  Opcode(Bytes!"11 04 17 00", 11),
  Opcode(Bytes!"11 03 14 00", 11),
];

void main(string[] args) {
  ////
  //Deal with invalid command-line arguments
  ////

  if (args.length < 4) {
    writeln("Give a moveset filename, the current Effect ID, and the desired Effect ID.");
    return;
  }

  if (!args[1].endsWith(".dat") && !args[1].endsWith(".moveset")) {
    writeln("This probably isn't a moveset data portion file (.dat/.moveset).");
    return;
  }

  ////
  //Read data
  ////

  ubyte[] inFile = cast(ubyte[]) std.file.read(args[1]);

  uint oldGFXFileID = args[2].to!uint(16);
  auto newGFXFileID = toUbyteArray(args[3].to!uint(16))[2..$];

  ////
  //Find opcodes & make replacements
  ////

  foreach (op; opcodes) {
    string opString = op.bytes.toUint.to!string(16);
    auto slice = inFile[0..$];

    while (true) {
      slice = slice.find(op.bytes); 
      if (slice.length < 4) break;

      //skip over opcode (pointer to data is next)
      slice = slice[4..$];

      //it seems all offsets are off by 0x24
      uint paramAddr = toUint(slice[0..4]) + 0x24 + op.argOffset*8;
      if (paramAddr > inFile.length) continue;

      uint foundGFXFileID = toUint(inFile[paramAddr..paramAddr+2]);

      if (foundGFXFileID == oldGFXFileID) {
        writefln("Found a %s command, updating...", opString);        
        inFile[paramAddr..paramAddr+2] = newGFXFileID; 
      }
    }
  }

  ////
  //Write out file
  ////

  auto filename = args[1].replace(".dat", "_gfxported.dat").replace(".moveset", "_gfxported.moveset");
  writeln("Outputting to ", filename);
  std.file.write(filename, inFile);
}

uint parseUint(string s) {
  if (s.startsWith("0x")) return s[2..$].to!uint(16);
  return s.to!uint;
}

uint toUint(ubyte[] bytes) {
  if (bytes.length > 2) {
    return bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3];
  }
  else {
    return bytes[0] << 8 | bytes[1];
  }
}

ubyte[] toUbyteArray(uint n) {
  return [
    cast(ubyte) (n >> 24),
    cast(ubyte) ((n & 0x00FF0000) >> 16),
    cast(ubyte) ((n & 0x0000FF00) >> 8),
    cast(ubyte) ((n & 0x000000FF))
  ];
}

//format a ubyte array as a string for easier reading
template Bytes(string s) {
  enum Bytes = s.splitter.map!(x => x.to!ubyte(16)).array;
}