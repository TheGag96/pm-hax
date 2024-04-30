import std.stdio, std.file, std.algorithm, std.array, std.conv, std.string, std.bitmanip, std.typecons, std.range;

alias Opcode = Tuple!(ubyte[], "bytes", uint, "argOffset", bool, "topHalf");

auto opcodes = [
  //graphic effects
  Opcode(Bytes!"11 00 10 00", 1, false),
  Opcode(Bytes!"11 01 0A 00", 1, false),
  Opcode(Bytes!"11 02 0A 00", 1, false),
  Opcode(Bytes!"11 1A 10 00", 1, false),
  Opcode(Bytes!"11 1B 10 00", 1, false),
  Opcode(Bytes!"11 1C 10 00", 1, false),
  Opcode(Bytes!"0E 0B 02 00", 0, true),

  //sword glows
  Opcode(Bytes!"11 04 17 00", 2, false),
  Opcode(Bytes!"11 04 17 00", 6, false),
  Opcode(Bytes!"11 04 17 00", 12, false),
  Opcode(Bytes!"11 03 14 00", 2, false),
  Opcode(Bytes!"11 03 14 00", 6, false),
  Opcode(Bytes!"11 03 14 00", 12, false),
  
  //collisions
  Opcode(Bytes!"06 00 0D 00", 0, true),
  Opcode(Bytes!"06 08 02 00", 0, false),
  Opcode(Bytes!"06 0A 08 00", 1, false),
  Opcode(Bytes!"06 0E 11 00", 1, false),
  Opcode(Bytes!"06 0F 05 00", 1, false),
  Opcode(Bytes!"06 10 11 00", 2, false),
  Opcode(Bytes!"06 15 0F 00", 0, true),
  Opcode(Bytes!"06 2C 0F 00", 0, true),
];

uint[uint] boneMap;

void main(string[] args) {
  ///////////////////
  // Program setup //
  ///////////////////

  ////
  // Deal with invalid command-line arguments
  ////

  if (args.length < 3) {
    writeln("Give a moveset filename and a filename of the bone mappings file.");
    return;
  }

  if (!args[1].endsWith(".dat") && !args[1].endsWith(".moveset")) {
    writeln("This probably isn't a moveset data portion file (.dat/.moveset).");
    return;
  }

  ////
  // Read data
  ////

  ubyte[] inFile = cast(ubyte[]) std.file.read(args[1]);

  foreach (line; std.file.readText(args[2]).lineSplitter) {
    auto splitUp = line.split;
    boneMap[splitUp[0].parseUint] = splitUp[1].parseUint;
  }


  ////////////////////////////////////
  // Replace PSA command references //
  ////////////////////////////////////

  writeln("Changing bone IDs in PSA commands...");

  ////
  // Find opcodes & make replacements
  ////

  foreach (op; opcodes) {
    string opString = format("%08X", op.bytes.toUint);
    auto slice = inFile[0..$];

    while (true) {
      slice = slice.find(op.bytes); 
      if (slice.length < 4) break;

      //skip over opcode (pointer to data is next)
      slice = slice[4..$];

      //it seems all offsets are off by 0x24
      uint paramAddr = toUint(slice[0..4]) + 0x24 + op.argOffset*8;
      if (paramAddr > inFile.length) continue;

      writef("%s command: ", opString);
      processBone(inFile, paramAddr, op.topHalf);
    }
  }


  /////////////////////////////////
  // Search through data section //
  /////////////////////////////////

  uint dataTablePtr   = inFile.valueAt(0x4) + inFile.valueAt(0x8)*0x4;
  uint dataTableCount = inFile.valueAt(0xC);
  uint dataOffsetPtr;
  auto noHeader = inFile[0x20..$];

  foreach (a; 0..dataTableCount) {
    if (noHeader.valueAt(dataTablePtr+a*8+4) == 0) {
      dataOffsetPtr = noHeader.valueAt(dataTablePtr+a*8);
    }
  }

  uint miscDataPtr          = noHeader.valueAt(dataOffsetPtr + 0x10);
  uint finalSmashList       = noHeader.valueAt(miscDataPtr + 0x4);
  uint finalSmashListLength = noHeader.valueAt(miscDataPtr + 0x8);
  uint hurtBoxList          = noHeader.valueAt(miscDataPtr + 0xC);
  uint hurtBoxListLength    = noHeader.valueAt(miscDataPtr + 0x10);
  uint boneReferences1      = noHeader.valueAt(miscDataPtr + 0x24);
  uint itemBones            = noHeader.valueAt(miscDataPtr + 0x28);
  uint collisionData        = noHeader.valueAt(miscDataPtr + 0x40);
  uint boneFloats1          = noHeader.valueAt(dataOffsetPtr + 0x40);
  uint boneFloats2          = noHeader.valueAt(dataOffsetPtr + 0x44);
  uint boneReferences2      = noHeader.valueAt(dataOffsetPtr + 0x48);
  uint handBones            = noHeader.valueAt(dataOffsetPtr + 0x4C);
  uint modelVisibility      = noHeader.valueAt(dataOffsetPtr + 0x4);

  ////
  // Final Smash aura
  ///

  writeln("\nChanging bone IDs in the Final Smash aura data...");

  foreach (a; 0..finalSmashListLength) {
    processBone(noHeader, finalSmashList + a*0x14);
  }

  ////
  // Hurtboxes
  ////

  writeln("\nChanging bone IDs in the hurtbox data...");

  foreach (a; 0..hurtBoxListLength) {
    uint hurtBoxDataPtr = hurtBoxList + a*0x20 + 0x1C;
    uint dataVal = noHeader.valueAt(hurtBoxDataPtr);
    uint boneID = dataVal >> 23;

    if (boneID in boneMap) {
      uint newBoneID = boneMap[boneID];

      writefln("0x%X -> 0x%X", boneID, newBoneID);
      boneID = newBoneID;
    }
    else {
      writefln("0x%X -> (not in mappings)", boneID);
    }

    dataVal = dataVal & ((1 << 23)-1) | (boneID << 23);
    noHeader.setValueAt(hurtBoxDataPtr, dataVal);
  }

  ////
  // Bone references 1
  ////

  writeln("\nChanging bone IDs in the first BoneReferences list...");

  foreach (a; 0..10) {
    processBone(noHeader, boneReferences1 + a*0x4);
  }

  ////
  // Bone references 2
  ///

  writeln("\nChanging bone IDs in the second BoneReferences list...");
  
  foreach (a; 0..(boneReferences1-boneReferences2)/4) {
    processBone(noHeader, boneReferences2 + a*0x4);
  }

  ////
  // Item Bones
  ///

  //writeln("\nChanging bone IDs in the item bones data list...");

  processBone(noHeader, itemBones);
  processBone(noHeader, itemBones + 0x4);
  processBone(noHeader, itemBones + 0x8);

  ////
  // Collision Data
  ///

  writeln("\nChanging bone IDs in collision data...");

  uint collisionEntryList       = noHeader.valueAt(collisionData);
  uint collisionEntryListLength = noHeader.valueAt(collisionData + 0x4);

  foreach (a; 0..collisionEntryListLength) {
    uint collisionEntry              = noHeader.valueAt(collisionEntryList + a*0x4);
    uint collisionBoneDataList       = noHeader.valueAt(collisionEntry + 0x4);
    uint collisionBoneDataListLength = noHeader.valueAt(collisionEntry + 0x8);

    foreach (b; 0..collisionBoneDataListLength) {
      processBone(noHeader, collisionBoneDataList + b*0x4);
    }
  }

  ////
  // Bone Floats 1
  ///

  writeln("\nChanging bone IDs in BoneFloats1...");

  foreach (a; 0..3) {
    processBone(noHeader, boneFloats1 + a*0x1C);
  }
  
  ////
  // Bone Floats 2
  ///

  writeln("\nChanging bone IDs in BoneFloats2...");

  foreach (a; 0..(boneReferences2-boneFloats2)/0x1C) {
    processBone(noHeader, boneFloats2 + a*0x1C);
  }

  ////
  // Hand bones
  ///

  writeln("\nChanging bone IDs in the handbones list...");

  foreach (a; 0..4) {
    processBone(noHeader, handBones + a*0x4);
  }

  uint handBonesDataListLength = noHeader.valueAt(handBones + 4 * 0x4);
  uint handBonesDataList       = noHeader.valueAt(handBones + 5 * 0x4);

  foreach (a; 0..handBonesDataListLength) {
    processBone(noHeader, handBonesDataList + a*0x4);
  }

  ////
  // Model Visibility
  ///

  writeln("\nChanging bone IDs in the model visibility data...");

  auto modelVisEntries = noHeader.valueAt(modelVisibility);
  auto boneSwitchCount = noHeader.valueAt(modelVisibility + 0x4);

  auto hiddenList  = noHeader.valueAt(modelVisEntries);
  auto visibleList = noHeader.valueAt(modelVisEntries + 0x4);

  foreach (ptr; only(hiddenList, visibleList)) {
    foreach (a; 0..boneSwitchCount) {
      auto boneGroupListLength = noHeader.valueAt(ptr + a*0x8 + 0x4);
      if (boneGroupListLength == 0) continue;
      auto boneGroupList  = noHeader.valueAt(ptr + a*0x8);

      foreach (b; 0..boneGroupListLength) {
        auto boneGroupLength = noHeader.valueAt(boneGroupList + b*0x8 + 0x4);
        if (boneGroupLength == 0) continue;
        auto boneGroup  = noHeader.valueAt(boneGroupList + b*0x8);
        
        foreach (c; 0..boneGroupLength) {
          processBone(noHeader, boneGroup + c*0x4);
        }
      }
    }
  }

  ////////////////////
  // Write out file //
  ////////////////////

  auto filename = args[1].replace(".dat", "_boneported.dat").replace(".moveset", "_boneported.moveset");
  writeln("\nOutputting to ", filename);
  std.file.write(filename, inFile);

  writeln("\nNote: There are some things that this tool currently does not cover:");
  writeln("* The character attributes list");
  writeln("* Articles' attached bones (some aren't shown by PSA Compressor - be careful!)");
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

uint valueAt(ubyte[] file, uint address) {
  return file[address..address+4].toUint;
}


void setValueAt(ubyte[] file, uint address, uint value) {
  file[address..address+4] = value.toUbyteArray;
}

uint followPointerChain(ubyte[] file, uint start, uint[] offsets) {
  uint cur = start;
  foreach (x; offsets) {
    cur = file.valueAt(cur+x);
  }

  return cur;
}

void processBone(ubyte[] file, uint ptr, bool topHalf = false) {
  uint foundBoneID = topHalf ? toUint(file[ptr..ptr+2]) : toUint(file[ptr..ptr+4]);  

  if (foundBoneID in boneMap) {
    uint newBoneID = boneMap[foundBoneID];

    writefln("0x%X -> 0x%X", foundBoneID, newBoneID);
    
    if (topHalf) {
      ubyte[] newBoneBytes = toUbyteArray(newBoneID)[2..$];
      file[ptr..ptr+2] = newBoneBytes; 
    }
    else {
      ubyte[] newBoneBytes = toUbyteArray(newBoneID);
      file[ptr..ptr+4] = newBoneBytes; 
    }
  }
  else {
    writefln("0x%X -> (not in mappings)", foundBoneID);
  }
}

//format a ubyte array as a string for easier reading
template Bytes(string s) {
  enum Bytes = s.splitter.map!(x => x.to!ubyte(16)).array;
}