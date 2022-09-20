//
//  ObjcUtil.m
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

#import "ObjcUtil.h"

@implementation ObjcUtil

+(BOOL) enableAction: (void (^)(void))action{
    @try {
        action();
    } @catch( NSException* e) {
        return NO;
    }
    return YES;
}

@end
