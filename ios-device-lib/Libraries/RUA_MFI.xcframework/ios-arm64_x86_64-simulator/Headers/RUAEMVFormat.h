//
//  RUAEMVFormat.h
//  ROAMreaderUnifiedAPI
//
//  Created by Lebas Stevens on 29/03/2023.
//  Copyright © 2023 ROAM. All rights reserved.
//

#ifndef RUAEMVFormat_h
#define RUAEMVFormat_h

typedef NS_ENUM (NSInteger, RUAEmvFormat) {
    RUAEmvFormatHex = 0,
    RUAEmvFormatBCDNoSentinels = 1,
    RUAEmvFormatBCDWithSentinels = 2,
    RUAEmvFormatHexNoSentinelsPaddedWithSpaces = 3,
    RUAEmvFormatHexNoSentinels = 4,
    RUAEmvFormatAsciiPaddedWithSpaces = 5,
    RUAEmvFormatAsciiPaddedWithSpacesForceEqualsSeparator = 6,
    RUAEmvFormatAsciiForceEnding_F = 7,
    RUAEmvFormatHexForceEnding_F = 8,
    RUAEmvFormatRawTrack = 9
};

#endif /* RUAEMVFormat_h */
