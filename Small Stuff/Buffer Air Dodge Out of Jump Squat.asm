###################################################
Buffer Air Dodge Out of Jump Squat v1.1 [codes]
###################################################
.alias AirDodge_Loc = 0x805482A0
CODE @ $805482A0
{
	#+0x00 Pointer to injection
	word 0x00000002; word AirDodge_Loc+0x48

	#+0x08 Change Action: Requirement: Action=0x21, Requirement=Animation End
	word 0; word 0x00000021
	word 6; word 0x00000001
	#+0x18 Additional Action Requirement: Requirement Value Bit is Set: RA-Bit[7]
	word 6; word 0x00000008
	word 5; RA_Bit 7
	#+0x28 Change Action: Requirement: Action=0xB, Requirement=Animation End
	word 0; word 0x0000000B
	word 6; word 0x00000001
	#+0x38 Additional Action Requirement: Requirement Value Not Bit is Set: RA-Bit[7]
	word 6; word 0x80000008
	word 5; RA_Bit 7

	#+0x48 Injection Start
	word 0x02010200; word AirDodge_Loc+0x8	#Change Action: Requirement: Action=0x21, Requirement=Animation End
	word 0x02040200; word AirDodge_Loc+0x18	#Additional Action Requirement: Requirement Value Bit is Set: RA-Bit[7]
	word 0x02010200; word AirDodge_Loc+0x28	#Change Action: Requirement: Action=0xB, Requirement=Animation End
	word 0x02040200; word AirDodge_Loc+0x38	#Additional Action Requirement: Requirement Value Not Bit is Set: RA-Bit[7]
	word 0x00080000; word 0					#Return
}
CODE @ $80FC17E0
{
	word 0x00070100; word AirDodge_Loc		#Sub Routine: Injection
}

CODE @ $80548310
{
	#+0x00 Pointer to injection
	word 2; word AirDodge_Loc+0x90

	#+0x08 If: Requirement Value: Button Press Occurs: 3 (Shield)
	word 6; word 0x00000030
	word 0; word 3
	#+0x18 Bit Variable Set: RA-Bit[7] = True
	word 5; RA_Bit 7

	#+0x20 Injection Start
	word 0x000A0100; word AirDodge_Loc+0x78	#If: Requirement Value: Button Press Occurs: 3 (Shield)
	word 0x120A0100; word AirDodge_Loc+0x88	#	Bit Variable Set: RA-Bit[7] = True
	word 0x000F0000; word 0					#Endif
	word 0x00080000; word 0					#Return
}
CODE @ $80FAD86C
{
	word 0x00070100; word AirDodge_Loc+0x70	#Sub Routine: Injection
}