#################################################################################
L-Canceling/Edge Canceling v3.2 (red flash on miss) (2/2) [codes, Shanus, Yeroc, Dantarion, Wind Owl, Magus]
#################################################################################
.alias L_Cancel_Loc_B = 0x80548388
.macro RGBA(<arg1>,<arg2>,<arg3>,<arg4>)
{
	word 0; word <arg1> # red
	word 0; word <arg2> # green
	word 0; word <arg3> # blue
	word 0; word <arg4> # alpha
}

CODE @ $80548388
{
  	#+0x00 If: Comparison Compare: LA-Basic[90] > 0.0
	word 6; word 7;
	word 5; LA_Basic 90
	word 0; word 5
	word 1; word 0

	#+0x20 Flash Overlay Effect: Red=FF, Green=FF, Blue=FF, Alpha=DC
	%RGBA(255,255,255,220)	#White, but not completely solid. Flash overlay (Beginning)

	#+0x40 Change Flash Overlay Color: Transition Time=6, Red=FF, Green=FF, Blue=FF, Alpha=0
	word 0; word 6			#Frames to wait before terminating the flash
	%RGBA(255,255,255,000) 	#White, but clear. Flash overlay (Ending)

	#+0x68 Synchronous Timer: Frames=6.0
	word 1; scalar 6.0  	#Transition time for flash

	#+0x70 Pointer to injection
	word 2; word L_Cancel_Loc_B+0x78

	#+0x78 Injection Start
	word 0x02010200; word 0x80FAF3EC			#Change Action: Requirement: Action=E, Requirement=In Air
	word 0x00070100; word 0x80FABBB4			#Sub Routine: 2x80FAB68C
	word 0x000A0400; word L_Cancel_Loc_B		#If: Comparison Compare: LA-Basic[90] > 0.0
	word 0x21010400; word L_Cancel_Loc_B+0x20	#Flash Overlay Effect: Red=FF, Green=FF, Blue=FF, Alpha=DC
	word 0x21020500; word L_Cancel_Loc_B+0x40	#	Change Flash Overlay Color: Transition Time=6, Red=FF, Green=FF, Blue=FF, Alpha=0
	word 0x000E0000; word 0						#Else
	word 0x21010400; word L_Cancel_Loc_B+0xD8	#	Flash Overlay Effect: Red=FF, Green=00, Blue=00, Alpha=DF
	word 0x21020500; word L_Cancel_Loc_B+0xF8	#	Change Flash Overlay Color: Transition Time=6, Red=FF, Green=00, Blue=00, Alpha=0
	word 0x000F0000; word 0						#Endif
	word 0x00010100; word L_Cancel_Loc_B+0x68	#Synchronous Timer: Frames=6.0
	word 0x21000000; word 0						#Terminate Flash Effect
	word 0x00080000; word 0						#Return

	#+0xD8 Flash Overlay Effect: Red=FF, Green=00, Blue=00, Alpha=DF
	%RGBA(255,000,000,220)	#Red, but not completely solid. Flash overlay (Beginning)

	#+0xF8 Change Flash Overlay Color: Transition Time=6, Red=FF, Green=00, Blue=00, Alpha=0
	word 0; word 6			#Frames to wait before terminating the flash
	%RGBA(255,000,000,000)	#Red, but clear. Flash overlay (Ending)
}
CODE @ $80FC1C58
{
	word 0x00070100; word L_Cancel_Loc_B+0x70
}