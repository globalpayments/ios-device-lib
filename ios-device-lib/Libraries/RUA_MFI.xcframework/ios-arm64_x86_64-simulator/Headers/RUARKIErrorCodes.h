
/*
 * Copyright(c) 2015 - 2023. All Rights Reserved, Ingenico Inc.
 * WARNING : This code is generated, don't modify it.
 */

#ifndef RUARKIErrorCodes_h
#define RUARKIErrorCodes_h
/** RKIErrorCodes enumeration */
typedef NS_ENUM(NSInteger, RUARKIErrorCodes) {

	/** Perform a successful RKI. */
	RUARKIErrorCodesEM_SUCCESS  = 0,

	/** Something wrong during operation */
	RUARKIErrorCodesEM_ERROR  = 1,

	/** Don’t support this command. */
	RUARKIErrorCodesEM_DEV_CmdNotSupport  = 2,

	/** Random generation failed in device. */
	RUARKIErrorCodesEM_DEV_ErrorGeneratNonce  = 4,

	/** Failed to validate the signed data from RKMS. */
	RUARKIErrorCodesEM_DEV_VerifySignError  = 5,

	/** Failed to caculate RKMS distributed data content as hash value. */
	RUARKIErrorCodesEM_DEV_CalHashError  = 7,

	/** Failed to sign for data content in device side. */
	RUARKIErrorCodesEM_DEV_GenerateSignErr  = 10,

	/** Failed to get public key from RKMS encryption cert or signing cert. */
	RUARKIErrorCodesEM_DEV_GetRkmsPubKeyErr  = 11,

	/** Failed to get IP and Port in device side, maybe don’t download user config file into device in advance. */
	RUARKIErrorCodesEM_DEV_GetIPAndPortError  = 12,

	/** Failed to get encryption cert and signing cert from the device. */
	RUARKIErrorCodesEM_DEV_GetDevCrtError  = 18,

	/** Failed to parse the RKMS PKCS#7 certificate tree. */
	RUARKIErrorCodesEM_DEV_RecvRkmsCrtError  = 21,

	/** Failed to validate RKMS certificate tree. */
	RUARKIErrorCodesEM_DEV_VerRkmsCrtError  = 22,

	/** Wrong key name of symmetric keys, key naming should be implemented base on file naming convention. */
	RUARKIErrorCodesEM_DEV_WrongKeyName  = 26,

	/** Failed to get symmetric keys from RKMS. */
	RUARKIErrorCodesEM_DEV_GetSkError  = 32,

	/** Failed to get KBPK(&TK) from TR-34 blob. */
	RUARKIErrorCodesEM_DEV_GetTkError  = 33,

	/** Error code returned from RKM, please refer to RKMS<Futurex-RKMS_Series-TechRef-V2.PDF> */
	RUARKIErrorCodesEM_DEV_RecvRkmsRetErr  = 34,

	/** Failed to get “complete injection” command from PC/Mobile phone. */
	RUARKIErrorCodesEM_DEV_CompleteInjectErr  = 35,

	/** Failed to receive data, maybe timeout, wrong timeout parameter, also maybe wrong data format. */
	RUARKIErrorCodesEM_DEV_RecvMsgErr  = 36,

	/** Wrong parameters */
	RUARKIErrorCodesEM_DEV_ErrorParam  = 139,

	/** REC is empty in “CC” token of PEDI command */
	RUARKIErrorCodesEM_RKMS_EncCertIsNone  = 48,

	/** REC is empty in “CD” token of PEDI command */
	RUARKIErrorCodesEM_RKMS_SignCertIsNone  = 49,

	/** Random numbe is empty from RKMS. */
	RUARKIErrorCodesEM_RKMS_RandomNumIsNone  = 50,

	/** Key number is empty in “KN” token of PEDK command */
	RUARKIErrorCodesEM_RKMS_KeyNumIsNone  = 51,

	/** TR-34 blob is empty in “AP” token of PEDK command */
	RUARKIErrorCodesEM_RKMS_TR34BlobIsNone  = 52,

	/** TR-31 block is empty in “KB” token of PEDK command */
	RUARKIErrorCodesEM_RKMS_TR31BlockIsNone  = 53,

	/** Padding method is empty in “CE” token. */
	RUARKIErrorCodesEM_RKMS_PadMethodIsNone  = 54,

	/** Signed data is empty in “KA” token. */
	RUARKIErrorCodesEM_RKMS_SignedDataIsNone  = 55,

	/** Return code is empty in “AN” token of PEDI command */
	RUARKIErrorCodesEM_RKMS_ANIsNone  = 56,

	/** Return code is empty in “BB” token of PEDV */
	RUARKIErrorCodesEM_RKMS_BBIsNone  = 57,

	/** Failed to initialize socket. Please confirm whether the ip address and port are correct in advance. */
	RUARKIErrorCodesEM_RKMS_InitSocketErr  = 65,

	/** Failed to create socket. Please confirm whether the ip address and port are correct in advance. */
	RUARKIErrorCodesEM_RKMS_CreateSocketErr  = 66,

	/** Device group name is empty.Please input device group name in PC/Mobile phone interface. */
	RUARKIErrorCodesEM_RKMS_DGLenIsZero  = 67,

	/** Failed to set network parameters */
	RUARKIErrorCodesEM_RKMS_SetSocketTimeoutErr  = 68,

	/** Failed to send data of PEDI process */
	RUARKIErrorCodesEM_RKMS_SendPEDIErr  = 69,

	/** It’s timeout to receive data from RKMS.Please confirm network connectivity. */
	RUARKIErrorCodesEM_RKMS_RecvDataTimeOut  = 70,

	/** Failed to get tag of total command.Try to perform again.If the result is same, please confirm network connectivity. */
	RUARKIErrorCodesEM_RKMS_NotGetCmdTag  = 71,

	/** Failed to send data of PEDK process */
	RUARKIErrorCodesEM_RKMS_SendPEDKErr  = 72,

	/** Device is unlawful.Need to confirm whether this device was add to relevant device group in RKMS side. */
	RUARKIErrorCodesEM_RKMS_GetANVauleIsN  = 73,

	/** Failed to send data of PEDV */
	RUARKIErrorCodesEM_RKMS_SendPEDVErr  = 74,

	/** AM error code 01, Field out of range */
	RUARKIErrorCodesEM_RKMS_FiledOutOfRange  = 80,

	/** AM error code 02, Invalid character */
	RUARKIErrorCodesEM_RKMS_InvalidChar  = 81,

	/** AM error code 03, Value out of range */
	RUARKIErrorCodesEM_RKMS_ValueOutOfRange  = 82,

	/** AM error code 04, Token missing */
	RUARKIErrorCodesEM_RKMS_TokenMissing  = 83,

	/** AM error code 06, Master File Key missing */
	RUARKIErrorCodesEM_RKMS_MFKMissing  = 84,

	/** AM error code 08, Hardware failure */
	RUARKIErrorCodesEM_RKMS_HardwareFail  = 85,

	/** AM error code 09, Invalid message format */
	RUARKIErrorCodesEM_RKMS_InvalidMsgFormat  = 86,

	/** AM error code 13, Invalid message length */
	RUARKIErrorCodesEM_RKMS_InvalidMsgLen  = 87,

	/** AM error code 14, Communication error */
	RUARKIErrorCodesEM_RKMS_CommunicationErr  = 88,

	/** AM error code 19, Function not supported */
	RUARKIErrorCodesEM_RKMS_FunNotSupport  = 89,

	/** AM error code 34, Invalid token */
	RUARKIErrorCodesEM_RKMS_InvalidToken  = 90,

	/** AM error code 48, Invalid key block */
	RUARKIErrorCodesEM_RKMS_InvalidKeyBlock  = 91,

	/** AM error code 52, Function not found */
	RUARKIErrorCodesEM_RKMS_FunNotFound  = 92,

	/** AM error code 57, Invalid public key data */
	RUARKIErrorCodesEM_RKMS_InvalidPubKeyData  = 93,

	/** AM error code 58,Invalid private key data */
	RUARKIErrorCodesEM_RKMS_InvalidPriKeyData  = 94,

	/** AM error code 59,Invalid certificate data */
	RUARKIErrorCodesEM_RKMS_InvalidCertData  = 95,

	/** AM error code 60,Invalid certificate request */
	RUARKIErrorCodesEM_RKMS_InvalidCertRequest  = 96,

	/** AM error code 61,No certificates in PKCS #7 data */
	RUARKIErrorCodesEM_RKMS_NoCertsInPKCS7  = 97,

	/** AM error code 62,No names match specified name */
	RUARKIErrorCodesEM_RKMS_NoNamesMatchSpecName  = 98,

	/** AM error code 63, Incorrect key type */
	RUARKIErrorCodesEM_RKMS_IncorrectKeyType  = 99,

	/** AM error code 65, Invalid device */
	RUARKIErrorCodesEM_RKMS_InvalidDevice  = 100,

	/** AM error code 66, Device not identified */
	RUARKIErrorCodesEM_RKMS_DevNotIdentified  = 101,

	/** AM error code 67, Register key not in register slot */
	RUARKIErrorCodesEM_RKMS_RegKeyNotInRegSlot  = 102,

	/** AM error code 68, Default passwords - cannot load key */
	RUARKIErrorCodesEM_RKMS_CannotLoadKey  = 103,

	/** AM error code 70, Certificate algorithm mismatch */
	RUARKIErrorCodesEM_RKMS_CertsAlgoMismatch  = 104,

	/** AM error code 71, Device group does not support algorithm */
	RUARKIErrorCodesEM_RKMS_DGNotSupportAlgo  = 105,

	/** AM error code 72, Hashing algorithm missing */
	RUARKIErrorCodesEM_RKMS_HashAlgoMissing  = 106,

	/** AM error code 73, Error generating nonce */
	RUARKIErrorCodesEM_RKMS_GenerateNonceErr  = 107,

	/** AM error code 74, Version not supported */
	RUARKIErrorCodesEM_RKMS_VerNotSupported  = 108,

	/** AM error code 75, User certificate tree is not chain */
	RUARKIErrorCodesEM_RKMS_CertsTreeIsNotChain  = 109,

	/** AM error code 76, Error validating device name */
	RUARKIErrorCodesEM_RKMS_ValidateDevNameErr  = 110,

	/** AM error code 77, Command not supported in protocol version */
	RUARKIErrorCodesEM_RKMS_NoSupCmdInProtoVer  = 111,

	/** AM error code 78, Missing device encryption certificate */
	RUARKIErrorCodesEM_RKMS_MissDevEncCert  = 112,

	/** AM error code 79, Error creating key block structure */
	RUARKIErrorCodesEM_RKMS_CreateKBSErr  = 113,

	/** AM error code 80, Internal error */
	RUARKIErrorCodesEM_RKMS_InternalErr  = 114,

	/** AM error code 81, Error processing session key */
	RUARKIErrorCodesEM_RKMS_ProccessSKErr  = 115,

	/** AM error code 82, DEVICE IS LOCKED */
	RUARKIErrorCodesEM_RKMS_DevIsLocked  = 116,

	/** Failed to parse length of TLV */
	RUARKIErrorCodesEM_General_TLVLenghthErr  = 128,

	/** Failed to parse tag of TLV */
	RUARKIErrorCodesEM_General_TLVTagErr  = 129,

	/** Don’t reveive “RF” token from RKMS, this token must be returned. */
	RUARKIErrorCodesEM_General_NotHaveRF  = 130,

};

#endif // RUARKIErrorCodes_h
