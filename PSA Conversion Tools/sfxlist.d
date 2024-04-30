import std.stdio, std.file, std.algorithm, std.array, std.conv, std.string, std.getopt;

ubyte[][ubyte[]] mappings;

enum opcodes = [Bytes!"0A 00 01 00", Bytes!"0A 01 01 00", Bytes!"0A 02 01 00", Bytes!"0A 03 01 00", Bytes!"0A 09 01 00", Bytes!"0A 05 01 00", Bytes!"0A 0A 01 00"];

enum Verbosity { all, nocommon, expanded }
enum Format { hex, decimal }

Verbosity verbosity = Verbosity.all;
Format format = Format.hex;

void main(string[] args) {
  ////
  // Deal with command-line arguments
  ////


  auto result = getopt(
    args,
    "verbosity|v", &verbosity,
    "format|f", &format
  );

  if (result.helpWanted || args.length < 2) {
    writeln("Usage: sfxlist moveset_file.dat [--verbosity all|nocommon|expanded] [--format hex|decimal]");
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

  ////
  // Find opcodes & make replacements
  ////

  foreach (op; opcodes) {
    auto slice = inFile[0..$];

    while (true) {
      slice = slice.find(op); 
      if (slice.length < 4) break;

      //skip over opcode (pointer to data is next)
      slice = slice[4..$];

      //MoveDef header creates an offset of 0x20, plus 0x4 to skip the event parameter type
      uint idAddr = slice[0..4].toUint + 0x24;
      if (idAddr > inFile.length) continue;
      
      processSFX(inFile.valueAt(idAddr));      
    }
  }

  ////
  // Search through sound lists
  ////

  uint dataTablePtr   = inFile.valueAt(0x4) + inFile.valueAt(0x8)*4;
  uint dataTableCount = inFile.valueAt(0xC);
  uint dataOffsetPtr;
  auto noHeader = inFile[0x20..$];

  foreach (i; 0..dataTableCount) {
    if (noHeader.valueAt(dataTablePtr+i*8+4) == 0) {
      dataOffsetPtr = noHeader.valueAt(dataTablePtr+i*8);
    }
  }

  uint soundListsPtr = followPointerChain(noHeader, dataOffsetPtr, [0x10, 0x2C, 0x0]);

  foreach (a; 0..6) { //skipping soundlist5
    uint soundsPtr   = noHeader.valueAt(soundListsPtr+a*8);
    uint soundsCount = noHeader.valueAt(soundListsPtr+a*8+4);

    foreach (b; 0..soundsCount) {
      uint sfxID = noHeader.valueAt(soundsPtr+b*4);
      if (sfxID != 0xFFFFFFFF) processSFX(sfxID);
    }
  }
}

void processSFX(uint sfxID) {
  if      (verbosity == Verbosity.nocommon && sfxID <= 265)   return;
  else if (verbosity == Verbosity.expanded && sfxID < 0x4000) return;

  if (format == Format.decimal) writeln(sfxID);
  else writefln("%X", sfxID);
}

uint parseUint(string s) {
  if (s.startsWith("0x")) return s[2..$].to!uint(16);
  return s.to!uint;
}

uint toUint(ubyte[] bytes) {
  return bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3];
}

ubyte[] toUbyteArray(uint n) {
  return [
    cast(ubyte) (n >> 24),
    cast(ubyte) ((n & 0x00FF0000) >> 16),
    cast(ubyte) ((n & 0x0000FF00) >> 8),
    cast(ubyte) ((n & 0x000000FF))
  ];
}

uint valueAt(ubyte[] file, uint address) {
  return file[address..address+4].toUint;
}

uint followPointerChain(ubyte[] file, uint start, uint[] offsets) {
  uint cur = start;
  foreach (x; offsets) {
    cur = file.valueAt(cur+x);
  }

  return cur;
}

//format a ubyte array as a string for easier reading
template Bytes(string s) {
  enum Bytes = s.splitter.map!(x => x.to!ubyte(16)).array;
}