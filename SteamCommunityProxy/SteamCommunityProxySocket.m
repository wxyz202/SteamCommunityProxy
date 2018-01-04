//
//  SteamCommunityProxySocket.m
//  SteamCommunityProxy
//
//  Created by wxyz on 2018/1/3.
//  Copyright © 2018年 wxyz202. All rights reserved.
//

#import <CocoaAsyncSocket/GCDAsyncSocket.h>

#import "SteamCommunityProxySocket.h"

static NSString * const HOST = @"23.52.74.146";
static const uint16_t PORT = 443;
static const NSTimeInterval TIMEOUT = 20.0;

@interface SteamCommunityProxySocketConnection : NSObject <GCDAsyncSocketDelegate>

@property (assign, nonatomic) NSInteger identifier;
@property (strong, nonatomic) GCDAsyncSocket *clientSocket;
@property (strong, nonatomic) GCDAsyncSocket *serverSocket;
@property (copy, nonatomic) void (^finishBlock)(SteamCommunityProxySocketConnection *);

- (instancetype)initWithClientSocket:(GCDAsyncSocket *)clientSocket connectionId:(NSInteger)connectionId;

@end

@implementation SteamCommunityProxySocketConnection

- (instancetype)initWithClientSocket:(GCDAsyncSocket *)clientSocket connectionId:(NSInteger)connectionId {
    self = [self init];
    if (self) {
        self.identifier = connectionId;
        dispatch_queue_t delegateQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        [clientSocket synchronouslySetDelegate:self delegateQueue:delegateQueue];
        self.clientSocket = clientSocket;
        
        self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:delegateQueue];
        [self.serverSocket connectToHost:HOST onPort:PORT error:NULL];
        
        [self.clientSocket readDataWithTimeout:TIMEOUT tag:0];
        [self.serverSocket readDataWithTimeout:TIMEOUT tag:0];
    }
    return self;
}

# pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (sock == self.clientSocket) {
        [self.serverSocket writeData:data withTimeout:-1 tag:0];
    } else {
        [self.clientSocket writeData:data withTimeout:-1 tag:0];
    }
    [sock readDataWithTimeout:TIMEOUT tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err) {
        NSLog(@"err: %@", err);
    }
    if (sock == self.clientSocket) {
        self.clientSocket = nil;
        [self.serverSocket disconnect];
    } else {
        self.serverSocket = nil;
        [self.clientSocket disconnect];
    }
    if (!self.clientSocket && !self.serverSocket) {
        self.finishBlock(self);
    }
}

# pragma mark - Equility

- (NSUInteger)hash {
    return self.identifier;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[SteamCommunityProxySocketConnection class]]) {
        SteamCommunityProxySocketConnection *other = object;
        return other.identifier == self.identifier;
    } else {
        return NO;
    }
}

@end


@interface SteamCommunityProxySocket() <GCDAsyncSocketDelegate>

@property (strong, nonatomic) dispatch_queue_t queue;
@property (assign, nonatomic) NSInteger connectionId;
@property (strong, nonatomic) NSMutableSet<SteamCommunityProxySocketConnection *> *connections;
@property (strong, nonatomic) GCDAsyncSocket *listenSocket;

@end

@implementation SteamCommunityProxySocket

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        _connectionId = 1;
        _connections = [[NSMutableSet alloc] init];
        _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
    }
    return self;
}

- (void)run {
    [self.listenSocket acceptOnPort:PORT error:NULL];
    [self self];
}

# pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if (sock != self.listenSocket) {
        return;
    }
    
    NSInteger connectionId = self.connectionId;
    self.connectionId += 1;
    SteamCommunityProxySocketConnection *connection = [[SteamCommunityProxySocketConnection alloc] initWithClientSocket:newSocket connectionId:connectionId];
    [self.connections addObject:connection];
    connection.finishBlock = ^(SteamCommunityProxySocketConnection *connection) {
        dispatch_async(self.queue, ^{
            [self.connections removeObject:connection];
        });
    };
}

@end
