//
//  RSAE2EEKey.h
//  ROAMreaderUnifiedAPI
//
//  Created by Marco Madeira on 01/09/2023.
//  Copyright © 2023 ROAM. All rights reserved.
//

#import "BaseKeyMap.h"

@interface RSAE2EEKey : BaseKeyMap

-(id)initWithKeyName:(NSString *)keyName;
-(NSString*)toString;

@end
