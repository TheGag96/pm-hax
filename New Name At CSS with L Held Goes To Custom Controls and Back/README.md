Reversed, Coded, and Documented by ChaseMcDizzle

Overview: 

3 hooks, with a state variable stored at 80002800 that redirects setNextSequence to the desired screen
The state variable acts as a way for all of the other hooks to fire when they should.
--------------------------------
Hook 1: 
Hooks on OK at New name
This hook will first check if the name is new. If it is new, it will store the index of the name in a place that the custom controls page reads from to determine which name to load the screen for. It will also set a flag which will cause hook 2 to leave the CSS, and cause hook 3 to redirect setNextSequence so it will go to the custom controls page rather than the normal main menu page.

inject @ 8069b860

#make sure other player didn't enter at same time, prevents potential race condition (most likely not an issue but I was paranoid)
lis r17, 0x8000
ori r17,r17,0x2800
lwz r18, 0(r17)
cmpwi r18, 0
beq flagset

#reject name branch if flag != 0 aka reject new name if the other person entered a name at the same time but earlier
li r19, -1
lis r17, 0x8069
ori r17,r17,0xB890
mtctr r17
bctr

#check if this name already exists, if so, normal procedure (select that name)
flagset:
lis r18, 0xFFFF
ori r18,r18, 0xFFFF
cmpw r3, r18
bne namealreadyexists

#new name, set state variable to 1 which (for next 2 hooks) == hook 2. leave CSS, hook 3. go to controls page
li r18, 0x1
stw r18, 0(r17)

#store index of new name, store at offset of nested pointers 0x805a00E0, where the setNext[sqButton] reads from 
#so it will automagically load control page for the new name
lis r8, 0x805A
#ori r8,r8,0x0000
lwz r8, 0xE0(r8)
lwz r8, 0x1C(r8)
stb r19, 0x28(r8)

#this is the line we replaced with the hook
namealreadyexists:
cmpwi r3,0


-----------------------------
Hook 2:
Leave game if the leave flag is set.
This is a loop that is run multiple times per frame at the CSS that checks if the B button is pressed / held.
We hook here, and so every loop we check our state variable to see if someone just entered a new name, if so, we pretend like someone just exited the CSS. (this whole thing could be replaced by a proper call to changeNextScene or whatever, but this is/was easier to reverse/develop)


inject @ 8068d7c0

#check if our state variable is set to 1 which == someone entered a new name
lis r8, 0x8000
ori r8,r8,0x2800
lwz r8, 0(r8)
cmpwi r8,0
beq replacedline
#New name was entered, lets set leave, to controls page
#set up necessary register values
li r0, 0xc
li r3, 0x4
li r6, 0x4
li r29, 0x4
li r30, 0x55
li r31, 0x3
#branch to leave vs. menu line and dont link because we just want it to leave
lis r16, 0x8068
ori r16,r16,0xd7f4
mtctr r16
bctr
replacedline:
cmpw r0, r30

-------------------

Hook 3:
Set Next Sequence hook
This is the function that is called when transitioning from different types of menus, main menu | CSS | controls page, etc
We hook here to see if the state variable is 1, which means a new name was just entered so, instead of having it go to the main menu, we change R4, which is the value of what sequence it wants to go to, to custom controls page.
If the state variable is 2, that means we are leaving the custom controls page, and instead of it going to the main menu, we want to redirect it (change r4) to go back to the CSS screen. 

inject @ 8002d654

#check state variable
lis r8, 0x8000
ori r8,r8,0x2800
lwz r8, 0(r8)
#if state variable is 0 then let setNextSequence run its natural course
cmpwi r8,0
beq replacedline
#if state variable is 1 then that means we should be redirecting to the controls page
cmpwi r8,1
beq tocontrols
#if state variable is 2 then that means we should be redirecting from the controls page back to CSS
cmpwi r8,2
beq backtoversus

#code to run if we are going to controls page
#replace r4 with the controls sequence
tocontrols:
lis r4, 0x8070
ori r4,r4, 0x18ec
#set flag to state 2, meaning when we leave controls it go back to vs.
li r7, 0x2
lis r8, 0x8000
ori r8,r8,0x2800
stw r7, 0(r8)
b replacedline

#code to run if we are leaving the controls page after having gone there from the CSS
backtoversus:
#replace r4 with the vs. menu sequence
lis r4, 0x8070
ori r4,r4, 0x17e0
#set state back to 0 meaning setNextSequence will act normally until a new name is entered at CSS again
li r7, 0x0
lis r8, 0x8000
ori r8,r8,0x2800
stw r7, 0(r8)

#replace line that we overwrote for the hook
replacedline:
mr r26, r3

---------------------------------------
**NOTE: This only works at the VS. Screen for the moment. It can easily be adjusted to account for other CSS screens
Converted to gecko code: 
$New Name at CSS goes to custom controls & back to CSS v1.2 [ChaseMcDizzle]
C269B860 0000000B
3E208000 62312800
82510000 2C120000
41820018 3A60FFFF
3E208069 6231B890
7E2903A6 4E800420
3E40FFFF 6252FFFF
7C039000 4082001C
3A400001 92510000
3D00805A 810800E0
8108001C 9A680028
2C030000 00000000
C268D7C0 00000009
3D008000 61082800
81080000 2C080000
4182002C 3800000C
38600004 38C00004
3BA00004 3BC00055
3BE00003 3E008068
6210D7F4 7E0903A6
4E800420 7C00F000
60000000 00000000
C202D654 0000000C
3D008000 61082800
81080000 2C080000
41820048 2C080001
4182000C 2C080002
41820020 3C808070
608418EC 38E00002
3D008000 61082800
90E80000 4800001C
3C808070 608417E0
38E00000 3D008000
61082800 90E80000
7C7A1B78 00000000