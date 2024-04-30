import std.stdio, std.file, std.algorithm, std.array, std.conv, std.string;

ubyte[][ubyte[]] mappings;

//enum opcodes = [Bytes!"0A 00 01 00", Bytes!"0A 01 01 00", Bytes!"0A 02 01 00", Bytes!"0A 03 01 00", Bytes!"0A 09 01 00"];
enum opcodes = [Bytes!"11 03 14 00", Bytes!"11 04 17 00"];

void main(string[] args) {
  ////
  //Deal with invalid command-line arguments
  ////

  if (args.length < 3) {
    writeln("Give a moveset filename and mappings file.");
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

  string mappingsTxt = readText(args[2]).strip;

  foreach (line; mappingsTxt.lineSplitter) {
    auto splitUp = line.split;
    mappings[splitUp[0].parseUint.toUbyteArray.idup] = splitUp[1].parseUint.toUbyteArray;
  }

  ////
  //Find opcodes & make replacements
  ////

  foreach (op; opcodes) {
    auto slice = inFile[0..$];

    while (true) {
      slice = slice.find(op); 
      if (slice.length < 4) break;

      //skip over opcode (pointer to data is next)
      slice = slice[4..$];

      //it seems all offsets are off by 0x24
      uint idAddr = toUint(slice[0..4]) + 0x24;
      if (idAddr > inFile.length) continue;
      ubyte[]* point = (inFile[idAddr..idAddr+4]) in mappings;

      if (point is null) {
        //writefln("No replacement for %X", toUint(inFile[idAddr..idAddr+4]));
        continue;
      }

      writefln("Found %X, changing to %X", toUint(inFile[idAddr..idAddr+4]), toUint(*point));

      inFile[idAddr..idAddr+4] = (*point);
    }
  }

  ////
  //Write out file
  ////

  auto filename = args[1].replace(".dat", "_traceconverted.dat").replace(".moveset", "_traceconverted.moveset");
  writeln("Outputting to ", filename);
  std.file.write(filename, inFile);
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

//format a ubyte array as a string for easier reading
template Bytes(string s) {
  enum Bytes = s.splitter.map!(x => x.to!ubyte(16)).array;
}