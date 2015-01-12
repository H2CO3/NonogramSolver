//
//  NonogramView.hpp
//  NonogramSolver
//
//  Created by Árpád Goretity on 29/12/14.
//  Copyright (c) 2014 H2CO3. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#undef check // so as to make Gecode happy

#import "Nonogram.hpp"

@class NonogramView;

@protocol NonogramViewDelegate <NSObject>

@property (nonatomic, readonly) Nonogram::Table &table;

- (void)nonogramViewChanged:(NonogramView *)nv;

@end

@interface NonogramView : NSView

@property (nonatomic, weak) id <NonogramViewDelegate> delegate;
@property (nonatomic, assign) BOOL interactionEnabled; // defaults to YES

- (void)reload;
- (void)startGlowAnimation;
- (void)stopGlowAnimation;

@end

