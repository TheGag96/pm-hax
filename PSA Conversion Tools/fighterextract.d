import std.stdio, std.file, std.process, std.algorithm, std.conv, std.string, std.bitmanip, std.container, std.range, std.regex, std.format;

struct CodePiece {
  string type;
  uint location;
}

enum FIGHTER_PAC = 0x80F9FC00;
enum FIGHTER_PAC_WORD_OFFSET = (FIGHTER_PAC-0x80000000u)/4;

void main(string[] args) {
  uint entryList = 0x2038C;
  uint exitList  = 0x207D4;
  auto app = appender!string;
  bool[uint] processedTable;

  //unloads RAM dump into array of 4-byte words (converted from big endian)
  uint[] dolphinDump = loadDump("ram.raw");
  uint[] mem2Dump;
  if (exists("aram.raw")) {
    mem2Dump = loadDump("aram.raw");
  }

  CodePiece[] actions;
  actions.reserve(0x112*2);

  foreach (i; 0..0x112) {
    auto entryOffset = dolphinDump[FIGHTER_PAC_WORD_OFFSET + i + entryList/4];

    if (entryOffset) {
      actions ~= CodePiece(
        format("Action %X (Entry)", i),
        entryOffset
      );
    }

    auto exitOffset = dolphinDump[FIGHTER_PAC_WORD_OFFSET + i + exitList/4];

    if (exitOffset) {
      actions ~= CodePiece(
        format("Action %X (Exit)", i),
        exitOffset
      );
    }
  }

  auto queue = DList!CodePiece(actions);

  while (!queue.empty) {
    auto front = queue.front;
    queue.removeFront;

    writefln("%s @ %08X:", front.type, front.location);

    char[] result;

    if (front.location < 0x80000000) {
      result = "This address is invalid.".dup;
    }
    else {
      result = readPSA(front.location, dolphinDump, mem2Dump);
    }

    static immutable re = ctRegex!`2-([89][0-9A-F]{7})`;

    auto matches = matchAll(result, re);

    foreach (match; matches) {
      auto subAddr = match[1].to!uint(16);

      //Change pointer args (2) to value args (0) so that you can call subroutines at absolute addresses properly. The
      //game had already converted the once-relative addresses to absolute ones when Fighter.pac loaded, and so if you
      //were to copy-paste the output of this script into a PSA and tried to run it in-game, it'd try to convert them
      //into absolute addresses AGAIN...
      match[0][0] = '0';

      if (subAddr !in processedTable) {
        queue.insertBack(CodePiece("Sub", subAddr));
        processedTable[subAddr] = true;
      }
    }

    writeln("  ", result, "\n");
  }
}

uint[] loadDump(string path) {
  ubyte[] raw    = cast(ubyte[]) read(path);
  uint[]  result = new uint[](raw.length/4);

  foreach (i; 0..result.length) {
    result[i] = raw[4*i] << 24 | raw[4*i+1] << 16 | raw[4*i+2] << 8 | raw[4*i+3];
  }

  return result;
}

uint readMem(uint addr, uint[] dolphinDump, uint[] mem2Dump) {
  if (addr < 0x90000000u) {
    uint index = (addr-0x80000000u)/4;
    return dolphinDump[index];
  }
  else {
    uint index = (addr-0x90000000u)/4;
    return mem2Dump[index];
  }
}

char[] readPSA(uint addr, uint[] dolphinDump, uint[] mem2Dump) {
  auto app     = appender!(char[]);
  uint curAddr = addr;

  while (true) {
    uint eventCode = readMem(curAddr, dolphinDump, mem2Dump);
    if (eventCode == 0x0 || eventCode == 0x00080000) break;

    uint argAddr   = readMem(curAddr+4, dolphinDump, mem2Dump);

    app.formattedWrite("E=%08X:", eventCode);

    foreach (a; 0..(eventCode >> 8) & 0xFF) {
      app.formattedWrite("%d-%08X,", readMem(argAddr+a*8, dolphinDump, mem2Dump), readMem(argAddr+a*8+4, dolphinDump, mem2Dump));
    }

    curAddr += 8;
  }

  return app.data;
}