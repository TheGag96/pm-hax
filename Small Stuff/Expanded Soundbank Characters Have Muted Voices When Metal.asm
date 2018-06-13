# To be inserted at 808611DC

start:
  # we don't care about non-expanded sounds
  cmpwi r4, 0x4000
  blt+ end

  mr r12, r4
  subi r12, r12, 0x4000
  li r0, 0xA5

  # perform modulus by 0xA5 to get within the range of a single soundbank
  divw r31, r12, r0
  mullw r31, r0, r31
  subc r12, r12, r31
  
  cmpwi r12, 0x2E # relative IDs 00-2E are voice clips, the rest are sound effects
  bgt- false
  cmpwi r12, 0x11 # ...but, crowd cheer (ouen) is not a voice clip
  beq- false

true:
  li r3, 1
  b end

false:
  li r3, 0

end:
  # restore overwritten code
  lwz r0, 0x14(sp)