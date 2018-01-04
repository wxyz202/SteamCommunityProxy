//
//  main.m
//  SteamCommunityProxy
//
//  Created by wxyz on 2018/1/2.
//  Copyright © 2018年 wxyz202. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SteamCommunityProxySocket.h"
#import "SteamCommunityProxyWebServer.h"

int main(int argc, const char * argv[]) {
    SteamCommunityProxySocket *proxySocket;
    SteamCommunityProxyWebServer *proxyWebServer;
    @autoreleasepool {
        proxySocket = [[SteamCommunityProxySocket alloc] init];
        [proxySocket run];
        proxyWebServer = [[SteamCommunityProxyWebServer alloc] init];
        [proxyWebServer run];
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
