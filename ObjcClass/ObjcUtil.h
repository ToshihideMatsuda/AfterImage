//
//  ObjcUtil.h
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjcUtil : NSObject
+(BOOL) enableAction: (void (^)(void))action;
+(NSString *) hardwareName ;
@end

NS_ASSUME_NONNULL_END
