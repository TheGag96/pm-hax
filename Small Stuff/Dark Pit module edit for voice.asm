##################################################
# Dark Pit Has a Different Voice Clip For Down-B #
# by codes and chasemcdizzle                     #
# Inserted to the end of Pit's module, Section 1 #
##################################################

# instruction at 0x9EB4 becomes b 0xCE14

enter:
  # get Entry offset from Fighter object (so we can find where this particular Entry object is located in the list)
  # assumes the pointer to the fighter is in r31
  lwz r4, 0x10c(r31) # offset mask is in r4 now
  rlwinm r4, r4, 0, 24, 31 # (000000ff) calculate offset constant

pointer_nonsense:
  # now to begin the pointer chain...
  lis r5, 0x8062
  ori r5, r5, 0x9A00

  # gets ftEntryManager pointer
  lwz r5, 0x154(r5) 

  # start of Entries
  lwz r5, 0x0(r5)

  # get number of bytes to skip to get to our entry
  mulli r4, r4, 580

  # now Entry address is in r5 
  add r5, r5, r4

  # grab port ID
  lwz  r5, 0x18(r5) 

find_costume_id:
  # shortcut to struct where list of fighters is stored
  lis r4, 0x805A
  lwz r4, 0x2D0(r4)

  # transform the port ID into an array index for an array inside the struct r4 points to
  # 0x0 -> 0x0, 0x1 -> 0x4, 0x2 -> 0x8, 0x3 -> 0xC
  rlwinm r5, r5, 2, 0, 29
  add. r4, r4, r5

  # if r4 doesn't look like a pointer, skip to pit
  # this patches reflecting SSE enemy stuff
  lis r5, 0x8000
  cmplw r4, r5
  blt- pit

  lwz r4, 0x4C(r4)

  # grab costume ID 
  lwz r4, 0x2A8(r4)

  # finally, check if costume is 5 or 7 (dark or retro dark)
  cmpwi r4, 5
  beq- dark_pit
  cmpwi r4, 7
  beq- dark_pit

pit:
  # load normal sound ID
  li r4, 0x2C8
  b after

dark_pit:
  # load dark pit sound ID
  li r4, 0x2CD

after:
  # jump back to place we hijacked
  b -0xCE68