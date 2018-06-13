# Small Stuff

This is a place for codes that aren't big enough to really need their own folder, but might be helpful to document nonetheless.

## Expanded Soundbank Characters Have Muted Voices When Metal

Author: codes

This is the code that's meant to be used with [JOJI's](http://ssbbhack.web.fc2.com/) Soundbank Expansion system to make it so that when soundbank clones are metal, their voice clips are muted. This works by hijacking the function `isVoiceId/[ftSoundIdExchangerImpl]` to count the right IDs for each soundbank as voice clips, not sound effects.

# Module edit for Dark Pit

Author: chasemcdizzle, codes

This is the ASM for the module edit that's done to make it so when Dark Pit reflects a projectile with his shield, he uses his own voice clip. It's inserted at the end of Section 1 of Pit's module.