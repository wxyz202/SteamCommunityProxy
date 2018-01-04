//
//  SteamCommunityProxyWebServer.m
//  SteamCommunityProxy
//
//  Created by wxyz on 2018/1/2.
//  Copyright © 2018年 wxyz202. All rights reserved.
//

#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataRequest.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>

#import "SteamCommunityProxyWebServer.h"

@interface SteamCommunityProxyWebServer()

@property (strong, nonatomic) GCDWebServer *webServer;
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation SteamCommunityProxyWebServer

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupURLSession];
        [self setupWebServer];
    }
    return self;
}

- (void)setupURLSession {
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    
}

- (void)setupWebServer {
    self.webServer = [[GCDWebServer alloc] init];
    GCDWebServerAsyncProcessBlock processBlock = ^(GCDWebServerDataRequest *request, GCDWebServerCompletionBlock completion) {
        NSMutableString *url = [request.URL.absoluteString mutableCopy];
        if ([url hasPrefix:@"http://"]) {
            [url replaceCharactersInRange:NSMakeRange(0, 4) withString:@"https"];
        }
        NSMutableURLRequest *realRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
        realRequest.HTTPMethod = request.method;
        realRequest.allHTTPHeaderFields = [request.headers copy];
        NSLog(@"headers = %@", request.headers);
        realRequest.HTTPBody = request.data;
        [[self.session dataTaskWithRequest:realRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                NSLog(@"%@", error);
            }
            if (!response) {
                completion([GCDWebServerResponse responseWithStatusCode:400]);
                return;
            }
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSString *contentType = httpResponse.allHeaderFields[@"Content-Type"];
            if (!contentType) {
                contentType = httpResponse.MIMEType;
            }
            if (!contentType) {
                contentType = @"application/octet-stream";
            }
            GCDWebServerDataResponse *realResponse = [[GCDWebServerDataResponse alloc] initWithData:data contentType:contentType];
            realResponse.statusCode = httpResponse.statusCode;
            realResponse.gzipContentEncodingEnabled = YES;
            [httpResponse.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, NSString *  _Nonnull obj, BOOL * _Nonnull stop) {
                if (![key isEqualToString:@"Content-Type"] && ![key isEqualToString:@"Content-Length"]) {
                    [realResponse setValue:obj forAdditionalHeader:key];
                }
            }];
            completion(realResponse);
        }] resume];
    };
    [self.webServer addDefaultHandlerForMethod:@"POST" requestClass:[GCDWebServerDataRequest class] asyncProcessBlock:processBlock];
    
    GCDWebServerProcessBlock redirectBlock = ^GCDWebServerResponse *(GCDWebServerDataRequest *request) {
        NSMutableString *url = [request.URL.absoluteString mutableCopy];
        if ([url hasPrefix:@"http://"]) {
            [url replaceCharactersInRange:NSMakeRange(0, 4) withString:@"https"];
        }
        return [GCDWebServerResponse responseWithRedirect:[NSURL URLWithString:url] permanent:NO];
    };
    
    [self.webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerDataRequest class] processBlock:redirectBlock];
    [self.webServer addDefaultHandlerForMethod:@"HEAD" requestClass:[GCDWebServerDataRequest class] processBlock:redirectBlock];
}

- (void)run {
    [self.webServer startWithOptions:@{GCDWebServerOption_ServerName:@"steamcommunity.com", GCDWebServerOption_Port: @(80), GCDWebServerOption_BindToLocalhost:@NO} error:NULL];
}

@end
