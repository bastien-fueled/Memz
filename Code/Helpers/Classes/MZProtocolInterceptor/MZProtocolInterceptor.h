//
//  MZProtocolInterceptor.h
//  Memz
//
//  Created by Bastien Falcou on 1/18/16.
//  Copyright © 2016 Falcou. All rights reserved.
//

#import <Foundation/Foundation.h>

/* In some cases, we may need to internally respond to delegate behavior directly in subclasses (i.e. scroll event
 * in UIScrollView subclass). However, the rest of the world still needs to be able to conform and listen to these delegate
 * callbacks. This class allows to keep our delegate, listen to messages sent along it, and forward messages outward 
 * after running some custom code.
 * This file implements an intermediate proxy class that avoids overriding all of the delegate methods manually.
 * Based on implementation provided below.
 * http://stackoverflow.com/questions/3498158/intercept-objective-c-delegate-messages-within-a-subclass
 */

@interface MZProtocolInterceptor : NSObject

@property (nonatomic, readonly, copy) NSArray *interceptedProtocols;
@property (nonatomic, weak) id receiver;
@property (nonatomic, weak) id middleMan;

- (instancetype)initWithInterceptedProtocol:(Protocol *)interceptedProtocol;
- (instancetype)initWithInterceptedProtocols:(Protocol *)firstInterceptedProtocol, ... NS_REQUIRES_NIL_TERMINATION;
- (instancetype)initWithArrayOfInterceptedProtocols:(NSArray *)arrayOfInterceptedProtocols;

@end
