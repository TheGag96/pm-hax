# Alternate Stage Loader Enhanced
Written by codes. This is an ASL with the following extra features:

* Lets expanded stage slots have alternate stages (stage expansion code included, stages are named STGEX## instead of STCUSTOM##)
* Allows for character-specific target tests (requires `54415247 00000100` as part of your stage data, filenames look like STGTARGETLv1##.pac where ## is the character's [CSS slot ID](https://www.dropbox.com/s/djmqofkkhjv7mf7/Fighter%20Chart.png?m=))

To use this with Legacy XP/TE, recompile the code after changing the lines mentioned in the source file.

The ASL here won't be detected by Mewtwo2000's ASL tool. I might need to make a new one...