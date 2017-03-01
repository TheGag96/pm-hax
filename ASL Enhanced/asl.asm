#To be inserted at 803FA360
#
#Note that the ASL tool likely won't recognize this code! Hopefully I can write
# a tool in the future to remedy this.
#
#To use with Legacy XP/TE or PMEX builds, check lines 22, 148, and 194
#For requiring exact button combinations, see line 169

start:
  #store registers somewhere to be restored
  stw r11, 0(r2)
  stw r7, 4(r2)
  stw r12, 8(r2)
  stw r3, 16(r2)
  stw r9, 20(r2)
  stw r14, 24(r2)
  
  #load string "proj" into r3
  lis r3, 0x7072 
  ori r3, r3, 0x6F6A
  
  #use these two lines instead for Legacy XP/TE (loads string "Lega")
  #lis r3, 0x4C65
  #ori r3, r3, 0x6761
  
  #don't continue if the file isn't in the mod's folder
  lwz r7, 32(r1)
  cmpw r3, r7
  bne- end
  
  #load string "/st_" into r3 (rel)
  lis r3, 0x2F73
  ori r3, r3, 0x745F
  
  #skip if we know the file is a module
  lwz r7, 50(r1)
  cmpw r3, r7
  beq- loc_1
  
  #load string "/STG" into r3 (pac)
  lis r3, 0x2F53
  ori r3, r3, 0x5447
  
  #if the file is not a stage then we shouldn't care about it
  lwz r7, 55(r1)
  cmpw r3, r7
  bne- end

  li r12, 0xACE
  
  #load first 4 letters of the loading stage's filename
  lwz r7, 59(r1)
  
  #check if we need to skip loc_2 if it starts with "EX"
  srawi r11, r7, 16
  cmpwi r11, 0x4558
  bne+ loc_2
  
  #make sure last letter is capitalized
  andi. r11, r7, 0xFF
  cmpwi r11, 0x61
  blt- after_capitalize
  subi r7, r7, 0x20
  
  b after_capitalize
  
loc_1:
  #load first 4 letters of the loading module's filename
  lwz r7, 54(r1)
  
  #take into account the "ex" case
  srawi r11, r7, 16
  cmpwi r11, 0x6578
  bne+ loc_2
  
  lis r11, 0x2020
  subc r7, r7, r11
  
  #make sure last letter is capitalized
  andi. r11, r7, 0xFF
  cmpwi r11, 0x61
  blt- after_capitalize
  subi r7, r7, 0x20
  
  b after_capitalize

loc_2:
  lis r11, 0xDFDF
  ori r11, r11, 0xDFDF
  and r7, r7, r11
  
after_capitalize:
  #805A7CB4 - 4?
  lis r11, 0x805A
  ori r11, r11, 0x7CB4
  cmpwi r12, 0xACE
  bne- loc_3
  subi r11, r11, 4

loc_3:
  #load pointer to data section
  lwz r11, 0(r11)

loc_loop:
  #load first 4 letters of stage name
  lwz r3, 0(r11)

  #load number of bottom combos
  lbz r9, 4(r11)

  #load number of random stages
  lbz r0, 5(r11)

  #read in character-specific flag
  lbz r14, 6(r11)

  #if r3 == 0xDED, then we've reached the end of the data section
  cmpwi r3, 0xDED
  beq- end

  #if r3 and r7 are the same string, then we've found the stage
  #we're trying to load an alt for
  cmpw r3, r7
  beq- loc_4

  #otherwise, skip ahead 8 bytes and continue the loop
  addi r11, r11, 8
  mulli r9, r9, 8
  addc r11, r11, r9
  b loc_loop
  
loc_4:
  #if there are no more button combos to check,
  #then go check if there are random alts
  cmpwi r9, 0
  beq- loc_8
  
  #skip ahead 8 bytes
  addi r11, r11, 8

  #load button code for the alt
  lhz r7, 0(r11)
  
  #load currently held button combination
  lis r3, 0x815E
  ori r3, r3, 0x8420

  #use these instead for Legacy XP / PMEX builds
  #lis r3, 0x8058
  #ori r3, r3, 0x58B8

  lhz r3, 2(r3)
  
  #load byte at 805882F8 into r10
  lis r10, 0x8059
  lbz r10, -0x7D08(r10)
  cmpwi r10, 1
  bne- loc_5
  
  #load half word at 805882FA into r10
  lis r10, 0x8059
  lhz r10, -0x7D06(r10)
  cmpwi r10, 0
  beq- loc_6
  b loc_7
  
loc_5:
  #if the combo for the alt == the buttons we're holding, start loading it
  #comment out the following line to require the button combination to be
  #  EXACTLY what is listed in the ASL data (can't hold down other buttons)
  and. r3, r7, r3
  cmpw r7, r3
  beq- loc_7

loc_6:
  #subtract 1 from the number of button combos and continue looping
  subi r9, r9, 1
  b loc_4
  
loc_7:
  #store current pointer to our data section into 805882FA
  lis r10, 0x8059
  sth r11, -0x7D06(r10)
  
  #get the alt code and begin loading
  lbz r3, 3(r11)
  b loc_9

loc_char:
  #load currently selected CSS slot ID
  lis r14, 0x8151
  ori r14, r14, 0xD41B

  #use these two lines instead for Legacy XP
  #lis r14, 0x814A
  #ori r14, r14, 0x835B

  #use these two lines for PMEX
  #lis r14, 0x814E
  #ori r14, r14, 0x9A9B

  lbz r3, 0(r14)

  #set up stage string (convert to hex)
  li r14, 4
  srw r14, r3, r14
  cmpwi r14, 0xA
  bge alpha_1
  addi r7, r14, 0x30
  b back_1   

alpha_1:
  addi r7, r14, 0x37
  
back_1:
  li r14, 8
  slw r7, r7, r14
  
  andi. r14, r3, 0xF
  add r7, r7, r14
  cmpwi r14, 0xA
  bge alpha_2
  addi r7, r7, 0x30
  b loc_9_jumpin  

alpha_2:
  addi r7, r7, 0x37

  b loc_9_jumpin
  
loc_8:
  #load based on character if char flag is set
  cmpwi r14, 1
  beq- loc_char

  #skip this if the stage isn't set to be random
  cmpwi r0, 0
  beq- end
  
  #load random seed from 805858BC
  lis r3, 0x8058
  ori r3, r3, 0x58BC
  lwz r3, 0(r3)
  
  #perform modulous to get random value
  divw r9, r3, r0
  mullw r9, r0, r9
  subc r3, r3, r9

loc_9:
  #load string "_A" into r7, then add r3 to it to get the ending of the chosen alt
  li r7, 0x5F41
  add r7, r7, r3

loc_9_jumpin:
  #store that string at the end of the stage filename (wherever (r6)-4 is)
  sth r7, -4(r6)
  
  #load string ".rel" into r3
  lis r3, 0x2E72
  ori r3, r3, 0x656C
  
  #branch if it's not a .pac
  cmpwi r12, 0xACE
  bne- loc_a

  #load string ".PAC" into r3
  lis r3, 0x2E50
  ori r3, r3, 0x4143
  
loc_a:
  #store alt letter string at end of filename and modify pointers to reflect the length change
  stw r3, -2(r6)
  subi r5, r5, 2
  addi r6, r6, 2
  
end:
  #load back old values of registers before this code was ran
  lwz r11, 0(r2)
  lwz r7, 4(r2)
  lwz r12, 8(r2)
  lwz r3, 16(r2)
  lwz r9, 20(r2)
  li r0, 0
