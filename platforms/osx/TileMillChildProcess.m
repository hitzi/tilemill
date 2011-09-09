//
//  TileMillChildProcess.m
//  tilemill
//
//  Created by Will White on 8/2/11.
//  Copyright 2011 Development Seed. All rights reserved.
//

#import "TileMillChildProcess.h"

@interface TileMillChildProcess ()

@property (nonatomic, retain) NSTask *task;
@property (nonatomic, retain) NSString *basePath;
@property (nonatomic, retain) NSString *command;
@property (nonatomic, assign, getter=isLaunched) BOOL launched;

- (void)receivedData:(NSNotification *)notification;

@end

#pragma mark -

@implementation TileMillChildProcess

@synthesize delegate;
@synthesize task;
@synthesize basePath = _basePath;
@synthesize command = _command;
@synthesize launched;

- (id)initWithBasePath:(NSString *)basePath command:(NSString *)command
{
    self = [super init];
    
    if (self)
    {
        _basePath = [basePath retain];
        _command  = [command retain];
    }

    return self;
}

- (void)dealloc
{
    [self stopProcess];

    [task release];
    [_basePath release];
    [_command release];

    [super dealloc];
}

#pragma mark -

- (void)startProcess
{
    if ([(id <NSObject>)self.delegate respondsToSelector:@selector(childProcessDidStart:)])
        [self.delegate childProcessDidStart:self];
 
    self.task = [[[NSTask alloc] init] autorelease];
    
    [self.task setStandardOutput:[NSPipe pipe]];
    [self.task setStandardError:[self.task standardOutput]];
    [self.task setCurrentDirectoryPath:self.basePath];
    [self.task setLaunchPath:self.command];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [self.task setArguments:[NSArray arrayWithObjects:[NSString stringWithFormat:@"--port=%i",       [defaults integerForKey:@"serverPort"]],
                                                      [NSString stringWithFormat:@"--bufferSize=%i", [defaults integerForKey:@"bufferSize"]],
                                                      [NSString stringWithFormat:@"--files=%@",      [defaults stringForKey: @"filesPath"]], 
                                                      nil]];

    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(receivedData:) 
                                                 name:NSFileHandleReadCompletionNotification 
                                               object:[[self.task standardOutput] fileHandleForReading]];
    
    [[[self.task standardOutput] fileHandleForReading] readInBackgroundAndNotify];
    
    [self.task launch];    
}

- (void)stopProcess
{
    NSData *data;

    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSFileHandleReadCompletionNotification 
                                                  object:[[self.task standardOutput] fileHandleForReading]];

    [self.task terminate];

    if ([(id <NSObject>)self.delegate respondsToSelector:@selector(childProcess:didSendOutput:)])
        while ((data = [[[self.task standardOutput] fileHandleForReading] availableData]) && [data length])
            [self.delegate childProcess:self didSendOutput:[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];

    if ( ! [self.task isRunning])
        if ([(id <NSObject>)self.delegate respondsToSelector:@selector(childProcessDidFinish:)])
            [self.delegate childProcessDidFinish:self];
}

- (void)receivedData:(NSNotification *)notification
{
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    if ([data length])
    {
        NSString *message = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

        if ([(id <NSObject>)self.delegate respondsToSelector:@selector(childProcess:didSendOutput:)])
            [self.delegate childProcess:self didSendOutput:message];
        
        if ([message hasPrefix:@"Started"] && ! self.isLaunched)
        {
            self.launched = YES;
            
            if ([(id <NSObject>)self.delegate respondsToSelector:@selector(childProcessDidSendFirstData:)])
                [self.delegate childProcessDidSendFirstData:self];
        }
    }

    else
        [self stopProcess];
    
    [[notification object] readInBackgroundAndNotify];  
}

@end