# PSA Conversion Tools

This folder contains tools that can be used to extract/manipulate PSA code.

## PSA to Gecko

Written by codes. This is a command-line tool that can generate global PSA Gecko codes from commands copied from PSA Compressor. The resulting codes are much like how Project M made edits to Fighter.pac and can be standalone or automatically hijack at an address of your choice.

To use, copy some PSA commands in PSA Compressor, and save them to a text file (e.g. `mypsa.txt`). (Note: You don't need to include a `Return` command - the tool will add one for you.) Then, run the program like so:

```bat
psa2gecko.exe
```

You will be prompted for 3 things, like this:

```
Main code insertion address: <where you want the code to write to>
Hijack address (0 if standalone): <where you want to insert a subroutine call to jump to your code, or 0 if you don't want to hijack at all>
Code file path: <path to the file containing your PSA commands>
```

Alternatively, you can just provide all of these arguments in the command prompt like so:

```bat
psa2gecko.exe 805482A0 80FAD86C mypsa.txt
```

In the future, it would be nice to output this code in the more descriptive code format that can be used with GCTRealMate (Project+'s GCT compiling system). For now, you would need to convert it by hand after the fact if you wanted that.

## Fighter.pac Extractor

Written by codes. This is a command-line tool that is able to extract the entirety of Fighter.pac, including all action entry and exit routines and the subroutines they call, and outputting them in a format you can copy and paste into PSA Compressor. It does this by reading from a RAM dump, meaning that the results of global Fighter.pac code edits made by PM/P+ can be naturally read. (This is especially helpful for implementing Action Overrides on a moveset, since now you can copy-paste the original and then simply modify, not worrying whether you're leaving out important normal functionality.)

To use, you'll need to get a RAM dump boot the game up in Dolphin, far enough in to where you know all Fighter.pac is loaded and the Gecko codes for it are applied (just get to the CSS or in game). Then go to View -> Memory and click "Dump MRAM". In your Dolphin directory, go to `User/Dump`, and copy the resulting file into the same directory as `fighterextract.exe` as `ram.raw`. Then, run on the command line with:

```bat
fighterextract.exe > extracted.txt
```

Example output:

```
Action 0 (Entry) @ 80FC1718:
  E=00070100:0-80FC16E0,E=00070100:0-80FAB894,

Action 1 (Entry) @ 80FABD5C:
  E=120A0100:5-22000010,E=02010200:0-0000000E,6-00000004,E=00070100:0-80FAB68C,E=020A0100:0-00000001,E=020A0100:0-00000002,E=020A0100:0-00000003,E=020A0100:0-00000004,E=020A0100:0-00000005,E=020A0100:0-00000006,E=020A0100:0-00000007,E=020A0100:0-00000008,E=02090200:0-00000008,0-0000273E,E=02090200:0-00000008,0-0000274B,E=02010500:0-00000002,6-00000007,5-000003F5,0-00000000,5-00000C2D,E=02040400:6-00000007,5-00000027,0-00000000,1-0000EA60,E=02040100:6-00000003,E=02010500:0-00000002,6-00000007,5-000003F3,0-00000000,1-00000000,E=02040400:6-00000007,5-00000027,0-00000000,1-0000EA60,E=02040100:6-00000003,E=02010500:0-00000000,6-00000007,5-000003F5,0-00000000,5-00000C2D,E=02040100:6-00000003,E=02010500:0-00000000,6-00000007,5-000003F3,0-00000000,1-00000000,E=02040100:6-00000003,E=02000400:0-0000271A,0-0000008C,6-00002714,0-00000003,E=02040100:6-00000003,E=02080100:0-0000271A,E=0D000200:0-00000009,0-80FABB4C,

Action 2 (Entry) @ 80FABE6C:
  E=00070100:0-80FC16E0,E=02010200:0-00000000,6-00000001,E=04000300:0-0000000D,3-00000000,1-00000000,

(...)
```

This program was written in [D](http://dlang.org).