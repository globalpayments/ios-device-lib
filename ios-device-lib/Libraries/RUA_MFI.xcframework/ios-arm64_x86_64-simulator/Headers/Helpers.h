//
//  Helpers.h
//  ROAMreaderUnifiedAPI
//
//  Created by Antoine Robiez on 29/11/2023.
//  Copyright © 2023 ROAM. All rights reserved.
//

#ifndef Helpers_h
#define Helpers_h
#import "ResponseMap.h"

@interface Helpers : NSObject

+ (NSMutableString*) NewStringBuilder: (NSString*)string;
+ (NSString*) StringToHexString: (NSString*)string;
+ (int) StringLength: (NSString*)string;
+ (NSMutableString*)Int16ToHexString:(int)integer;
+ (void)AppendString:(NSMutableString*)string :(NSString*)stringToAppend;
+ (NSString*)StringBuilderToString: (NSMutableString*)string;
+ (ResponseMap*)NewResponseMap;
+ (NSString*)TrimWhiteSpaces:(NSString*)string;
+ (NSString*)BytesToString:(NSData*)response :(int)currIndex :(int)length;
+ (int) BytesToInt32:(NSData*)response :(int)currIndex;
+ (NSDictionary*)JsonParseString: (NSString*) jsonString;
+ (NSDictionary*)JsonGetSubNode: (NSDictionary*) jsonNode:(NSString*)name;
+ (NSString*)JsonGetStringNodeOrDefault: (NSDictionary*)jsonNode :(NSString*)name :(NSString*)defaultValue;
+ (int)GetBytesLength: (NSData*)bytes;

@end

#endif /* Helpers_h */
