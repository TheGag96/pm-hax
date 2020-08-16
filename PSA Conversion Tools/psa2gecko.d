import std.stdio, std.algorithm, std.conv, std.string, std.array, std.file, std.typecons;
import std.format : formattedWrite;

alias Parameter = Tuple!(uint, "type", uint, "value");
alias Command   = Tuple!(uint, "event", Parameter[], "params");

int main(string[] args) {
  ////
  // Read arguments
  ////

  uint mainCodeAddr, hijackAddr;
  string code;

  if (args.length == 4) {
    mainCodeAddr = args[1].strip.replace("0x", "").to!uint(16);
    hijackAddr   = args[2].strip.replace("0x", "").to!uint(16);
    code         = args[3].strip;
  }
  else if (args.length == 1) {
    write("Main code insertion address: ");
    mainCodeAddr = readln.strip.replace("0x", "").to!uint(16);

    write("Hijack address (0 if standalone): ");
    hijackAddr = readln.strip.replace("0x", "").to!uint(16);

    write("Code file path: ");
    code = readText(readln.strip).strip;
  }
  else {
    writeln("Usage: psa2gecko.exe <insertion address> <hijack address> <path to psa code file>");
    writeln("Alternatively, run with no arguments, and you'll be prompted for them.");
    return 1;
  }

  bool highAddress   = mainCodeAddr >= 0x90000000;
  bool notStandalone = hijackAddr != 0;


  ////
  // Parse/output Gecko code
  ////

  auto commands = parseCommands(code);

  auto outCode = appender!string;
  uint counter = mainCodeAddr;

  uint paramsLength   = cast(uint) (commands.map!(x => x.params.length).sum*8 + 8 * notStandalone);
  uint mainCodeLength = cast(uint) (commands.length*8 + paramsLength + 8);

  if (highAddress) {
    outCode.put("4A000000 90000000\n");
    outCode.formattedWrite("16%06X %08X\n", mainCodeAddr & 0xFFFFFF, mainCodeLength);
  }
  else {
    outCode.formattedWrite("06%06X %08X\n", mainCodeAddr & 0xFFFFFF, mainCodeLength);
  }

  if (notStandalone) {
    outCode.formattedWrite("00000002 %08X\n", mainCodeAddr + paramsLength);
    counter += 8;
  }

  uint[] cmdPtrs = new uint[](commands.length);

  foreach (i, command; commands) {
    cmdPtrs[i] = counter;

    foreach (param; command.params) {
      outCode.formattedWrite("%08X %08X\n", param.type, param.value);

      counter += 8;
    }
  }

  foreach (i, command; commands) {
    if (command.params.length) {
      outCode.formattedWrite("%08X %08X\n", command.event, cmdPtrs[i]);
    }
    else {
      outCode.formattedWrite("%08X 00000000\n", command.event);
    }
  }

  outCode.put("00080000 00000000\n");

  if (notStandalone) {
    outCode.formattedWrite("06%06X 00000008\n", hijackAddr & 0xFFFFFF);
    outCode.formattedWrite("00070100 %08X\n", mainCodeAddr);
  }

  writeln(outCode.data);

  return 0;
}

Command[] parseCommands(string s) {
  Command[] result;

  while (s.length) {
    Command curCom;

    curCom.event = s[2..10].to!uint(16);
    s = s[11..$];

    foreach (x; 0..(curCom.event >> 8) & 0xFF) {
      Parameter curParam;

      curParam.type  = s[0..1].to!uint(16);
      curParam.value = s[2..10].to!uint(16);

      s = s[11..$];

      curCom.params ~= curParam;
    }

    result ~= curCom;
  }

  return result;
}
