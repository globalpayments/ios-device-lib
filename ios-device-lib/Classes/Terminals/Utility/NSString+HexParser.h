//
//  NSString+HexParser.h
//  ios-device-lib
//
//  Created by Desimini, Wilson on 10/5/22.
//

#import <Foundation/Foundation.h>

@interface NSString (HexParser)

+ (instancetype)stringWithHex:(NSString *)hex;
- (instancetype)convertedFromHexadecimal;

@end
