//
//  ObjcUtil.m
//  AfterImage
//
//  Created by tmatsuda on 2022/09/20.
//

#import "ObjcUtil.h"
#import <sys/sysctl.h>

@implementation ObjcUtil

+(BOOL) enableAction: (void (^)(void))action{
    @try {
        action();
    } @catch( NSException* e) {
        return NO;
    }
    return YES;
}

+(NSString *) hardwareName{
    // sysctlbynameを使用
    size_t size;
    sysctlbyname("hw.machine",NULL,&size,NULL,0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine",machine,&size,NULL,0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);

    return platform;
}
@end
