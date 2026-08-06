//
//  RUAMSRFormat.h
//  ROAMreaderUnifiedAPI
//
//  Created by Occ Mobility on 14/12/2022.
//  Copyright © 2022 ROAM. All rights reserved.
//

#ifndef RUAMSRFormat_h
#define RUAMSRFormat_h

typedef NS_ENUM (NSInteger, RUAMSRFormat) {
    RUAMSRFormatHex = 0,
    RUAMSRFormatBCDNoSentinels = 1,
    RUAMSRFormatBCDWithSentinels = 2,
    RUAMSRFormatHexNoSentinelsPaddedWithSpaces = 3,
    RUAMSRFormatHexNoSentinels = 4,
    RUAMSRFormatAsciiPaddedWithSpaces = 5,
    RUAMSRFormatAsciiPaddedWithSpacesForceEqualsSeparator = 6,
    RUAMSRFormatAsciiForceEndingF = 7,
    RUAMSRFormatHexForceEndingF = 8,
    RUAMSRFormatRawTrack = 9
} ;

#endif /* RUAMSRFormat_h */
