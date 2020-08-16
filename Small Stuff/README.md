# Small Stuff

This is a place for codes that aren't big enough to really need their own folder, but might be helpful to document nonetheless.

## Expanded Soundbank Characters Have Muted Voices When Metal

Author: codes

This is the code that's meant to be used with [JOJI's](http://ssbbhack.web.fc2.com/) Soundbank Expansion system to make it so that when soundbank clones are metal, their voice clips are muted. This works by hijacking the function `isVoiceId/[ftSoundIdExchangerImpl]` to count the right IDs for each soundbank as voice clips, not sound effects.

## Module edit for Dark Pit

Author: chasemcdizzle, codes

This is the ASM for the module edit that's done to make it so when Dark Pit reflects a projectile with his shield, he uses his own voice clip. It's inserted at the end of Section 1 of Pit's module.

## Buffer Air Dodge Out of Jump Squat

Author: codes

This is a global PSA injection that makes it so you can buffer an air dodge / wavedash input during jump squat. This makes airdodging as easy as pressing jump and shield simultaneously, instead of having to time the shield press a few frames after jump (which is different for each character). When you do, you'll immediately be wavedashing the moment the jump squat animation ends (a perfectly-timed wavedash). This makes things work much like Slap City, Rivals, and Icons.

When inserting this into your codeset, make sure that it goes **after all Project M PSA injections**, as this overwrites parts of some of them. You may either use the plain Gecko .txt, or the .asm file for GCTRealMate codesets (like Project+).