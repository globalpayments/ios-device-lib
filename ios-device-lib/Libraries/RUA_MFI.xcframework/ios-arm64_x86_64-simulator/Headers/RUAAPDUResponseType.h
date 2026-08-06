
/*
 * Copyright(c) 2015 - 2023. All Rights Reserved, Ingenico Inc.
 * WARNING : This code is generated, don't modify it.
 */

#ifndef RUAAPDUResponseType_h
#define RUAAPDUResponseType_h
/** [TODO] APDUResponseType documentation is missing. */
typedef NS_ENUM(NSInteger, RUAAPDUResponseType) {

	/** APDU answer will be returned in clear */
	RUAAPDUResponseTypeClear  = 0,

	/** APDU answer encrypted with ROAM Encryption */
	RUAAPDUResponseTypeRoamEncryption  = 1,

	/** APDU answer encrytped with OnGuard */
	RUAAPDUResponseTypeOnGuardEncryption  = 2,

};

#endif // RUAAPDUResponseType_h
