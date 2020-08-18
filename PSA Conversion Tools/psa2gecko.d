import std.stdio, std.algorithm, std.conv, std.string, std.array, std.file, std.typecons;
import std.format : formattedWrite;
import std.math   : log, round;

enum ParamType : uint {
  value = 0,
  scalar,
  pointer,
  boolean,
  type_4,
  variable,
  requirement
}

alias Parameter = Tuple!(ParamType, "type", uint, "value");
alias Command   = Tuple!(uint, "event", Parameter[], "params");

int main(string[] args) {
  ////
  // Read arguments
  ////

  uint mainCodeAddr, hijackAddr;
  string code;
  bool outputGctRealMate;

  ptrdiff_t realmateArgFound = args.countUntil(["--realmate"]);
  if (realmateArgFound != -1) {
    outputGctRealMate = true;
    args = args.remove(realmateArgFound);
  }

  if (args.length == 4) {
    mainCodeAddr = args[1].strip.replace("0x", "").to!uint(16);
    hijackAddr   = args[2].strip.replace("0x", "").to!uint(16);
    code         = readText(args[3].strip).strip;
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


  ////
  // Parse/output Gecko code
  ////

  auto commands = parseCommands(code);

  auto result = outputGctRealMate ? convertToRealMate(mainCodeAddr, hijackAddr, commands) :
                                    convertToGecko(mainCodeAddr, hijackAddr, commands);

  writeln(result);

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

      curParam.type  = cast(ParamType) s[0..1].to!uint(16);
      curParam.value = s[2..10].to!uint(16);

      s = s[11..$];

      curCom.params ~= curParam;
    }

    result ~= curCom;
  }

  return result;
}

string convertToGecko(uint mainCodeAddr, uint hijackAddr, Command[] commands) {
  auto outCode = appender!string;

  bool highAddress   = mainCodeAddr >= 0x90000000;
  bool notStandalone = hijackAddr != 0;

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


  return outCode.data;
}


string convertToRealMate(uint mainCodeAddr, uint hijackAddr, Command[] commands) {
  auto outCode = appender!string;

  bool highAddress   = mainCodeAddr >= 0x90000000;
  bool notStandalone = hijackAddr != 0;

  uint counter = mainCodeAddr;

  uint paramsLength   = cast(uint) (commands.map!(x => x.params.length).sum*8 + 8 * notStandalone);
  uint mainCodeLength = cast(uint) (commands.length*8 + paramsLength + 8);
  uint mainCodeDigits = cast(uint) (log(mainCodeLength) / log(16)) + 1;

  outCode.formattedWrite(".alias Code_Loc = 0x%08X\n", mainCodeAddr);
  outCode.formattedWrite("CODE @ $%08X\n{\n", mainCodeAddr);

  if (notStandalone) {
    outCode.formattedWrite("  # +0x%0*X Pointer to injection", mainCodeDigits, 0);
    outCode.formattedWrite("\n  word 2; word Code_Loc+0x%0*X\n\n", mainCodeDigits, paramsLength);
    counter += 8;
  }

  uint[] cmdPtrs = new uint[](commands.length);

  //outCode.formattedWrite("  # +0x%0*X Params\n", mainCodeDigits, counter-mainCodeAddr);

  foreach (i, command; commands) {
    cmdPtrs[i] = counter;

    if (command.params.length) {
      outCode.formattedWrite(
        "  # +0x%0*X Params for Code_Loc+0x%0*X\n",
        mainCodeDigits, counter-mainCodeAddr, mainCodeDigits, paramsLength + i*8
      );

      foreach (param; command.params) {
        outCode.formattedWrite("  %s\n", getParamValString(param));

        counter += 8;
      }
    }

  }

  outCode.formattedWrite("\n  # +0x%0*X PSA commands start\n", mainCodeDigits, counter-mainCodeAddr);

  foreach (i, command; commands) {
    if (command.params.length) {
      outCode.formattedWrite("  word 0x%08X; word Code_Loc+0x%0*X #\n", command.event, mainCodeDigits, cmdPtrs[i]-mainCodeAddr);
    }
    else {
      outCode.formattedWrite("  word 0x%08X; word 0x00000000  %*s#\n", command.event, mainCodeDigits, " ");
    }
  }

  outCode.formattedWrite("  word 0x00080000; word 0x00000000  %*s# Return\n}\n", mainCodeDigits, " ");

  if (notStandalone) {
    outCode.formattedWrite("CODE @ $%08X\n{\n", hijackAddr);
    outCode.formattedWrite("  # Subroutine injection\n", counter-mainCodeAddr);
    outCode.formattedWrite("  word 0x00070100; word Code_Loc\n}\n");
  }


  return outCode.data;
}

string getParamValString(Parameter param) {
  static immutable string[] memoryTypes  = ["IC", "LA", "RA"];
  static immutable string[] dataTypes    = ["Basic", "Float", "Bit"];
  static immutable string[] varTypeNames = ["Value", "Scalar", "Pointer", "Boolean", "(4)", "Variable", "Requirement"];

  if (param.type == ParamType.variable) {
    string memoryType = memoryTypes[param.value >> 28];
    string dataType   = dataTypes[(param.value >> 24) & 0xF];
    int    varId      = (param.value & 0x007FFFFF) * (param.value & 0x00800000 ? -1 : 1);

    return format("word %d; %s_%s %d", param.type, memoryType, dataType, varId);
  }
  else if (param.type == ParamType.scalar) {
    return format("word %d; scalar %s", param.type, (param.value / 60000.0).to!string);
  }
  else {
    return format("word %d; word 0x%08X # %s", param.type, param.value, varTypeNames[param.type]);
  }
}