//
//  NonogramView.mm
//  NonogramSolver
//
//  Created by Árpád Goretity on 29/12/14.
//  Copyright (c) 2014 H2CO3. All rights reserved.
//

#import "NonogramView.hpp"

#import <QuartzCore/QuartzCore.h>


#define NONOGRAM_CELL_SIZE 30.0
#define NONOGRAM_CELL_INSET 5.0

@interface NonogramView () {
	id <NonogramViewDelegate> delegate;
	BOOL interactionEnabled;
}

@end

@implementation NonogramView

- (id)initWithFrame:(CGRect)f {
	self = [super initWithFrame:f];

	if (self) {
		self.interactionEnabled = YES;
	}

	return self;
}

- (void)reload {
	const auto &table = self.delegate.table;

	self.frame = CGRectMake(
		0,
		0,
		(table.size() ? table.front().size() : 0) * NONOGRAM_CELL_SIZE,
		table.size() * NONOGRAM_CELL_SIZE
	);

	[self setNeedsDisplay:YES];
}

- (void)startGlowAnimation {
	self.frame = self.superview.bounds; // just to make sure it fills the screen
	CABasicAnimation *glowAnimation = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
	glowAnimation.fromValue = (id)[NSColor colorWithSRGBRed:0.2 green:0.8 blue:1.0 alpha:0.5].CGColor;
	glowAnimation.toValue = (id)[NSColor colorWithSRGBRed:0.2 green:0.8 blue:1.0 alpha:1.0].CGColor;
	glowAnimation.duration = 0.5;
	glowAnimation.autoreverses = YES;
	glowAnimation.repeatCount = HUGE_VALF;
	[self setWantsLayer:YES];
	[self.layer addAnimation:glowAnimation forKey:@"glow"];
}

- (void)stopGlowAnimation {
	[self.layer removeAnimationForKey:@"glow"];
	[self setWantsLayer:NO];
}

// Properties

- (id <NonogramViewDelegate>)delegate {
	return delegate;
}

- (void)setDelegate:(id <NonogramViewDelegate>)newDelegate {
	delegate = newDelegate;
	[self reload];
}

@synthesize interactionEnabled = interactionEnabled;

// Drawing

- (void)drawRect:(NSRect)rect {
	[super drawRect:rect];

	const auto &table = self.delegate.table;

	CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];

	for (std::size_t i = 0; i < table.size(); i++) {
		for (std::size_t j = 0; j < table[i].size(); j++) {
			CGRect cell = {
				{
					j * NONOGRAM_CELL_SIZE + NONOGRAM_CELL_INSET,
					i * NONOGRAM_CELL_SIZE + NONOGRAM_CELL_INSET
				},
				{
					NONOGRAM_CELL_SIZE - 2 * NONOGRAM_CELL_INSET,
					NONOGRAM_CELL_SIZE - 2 * NONOGRAM_CELL_INSET
				}
			};

			CGRect border {
				{
					j * NONOGRAM_CELL_SIZE,
					i * NONOGRAM_CELL_SIZE
				},
				{
					NONOGRAM_CELL_SIZE,
					NONOGRAM_CELL_SIZE
				}
			};

			static std::unordered_map<Nonogram::Cell, NSColor *, std::hash<unsigned char>> cellColors {
				{ Nonogram::CELL_BLACK,   [NSColor blackColor]      },
				{ Nonogram::CELL_WHITE,   [NSColor whiteColor]      },
				{ Nonogram::CELL_UNKNOWN, [NSColor lightGrayColor ] }
			};

			NSColor *cellColor = cellColors[table[i][j]];
			[cellColor setFill];
			CGContextFillRect(ctx, cell);

			[[NSColor lightGrayColor] setStroke];
			CGContextStrokeRect(ctx, border);
		}
	}

	CGContextFillPath(ctx);
}

// Mouse event handling

- (BOOL)eventIsInBounds:(NSEvent *)event getRow:(std::size_t *)pRow column:(std::size_t *)pCol {
	NSPoint coord = [self convertPoint:[event locationInWindow] fromView:nil];
	// Surprisingly, event coordinates are 1-based; the origin is at pixel (1, 1)
	std::size_t row = (coord.y - 1) / NONOGRAM_CELL_SIZE;
	std::size_t col = (coord.x - 1) / NONOGRAM_CELL_SIZE;

	const auto &table = self.delegate.table;
	// Only send in-bounds events
	if (row < table.size() and table.size() > 0 and col < table.front().size()) {
		*pRow = row;
		*pCol = col;
		return YES;
	}

	return NO;
}

- (void)redrawAndNotifyDelegate {
	[self setNeedsDisplay:YES];
	[self.delegate nonogramViewChanged:self];
}

// Right click toggles cell between black and white state
- (void)rightMouseUp:(NSEvent *)event {
	if (not self.interactionEnabled) {
		return;
	}

	std::size_t row, col;
	if ([self eventIsInBounds:event getRow:&row column:&col]) {
		if (delegate.table[row][col] == Nonogram::CELL_BLACK) {
			delegate.table[row][col] = Nonogram::CELL_WHITE;
		} else {
			delegate.table[row][col] = Nonogram::CELL_BLACK;
		}

		[self redrawAndNotifyDelegate];
	}
}

// Whereas pressing the left mouse button and dragging the cursor
// draws a path of black cells
- (void)mouseDown:(NSEvent *)event {
	if (not self.interactionEnabled) {
		return;
	}

	std::size_t row, col;
	if ([self eventIsInBounds:event getRow:&row column:&col]) {
		delegate.table[row][col] = Nonogram::CELL_BLACK;
		[self redrawAndNotifyDelegate];
	}
}

- (void)mouseDragged:(NSEvent *)event {
	if (not self.interactionEnabled) {
		return;
	}

	std::size_t row, col;
	if ([self eventIsInBounds:event getRow:&row column:&col]) {
		delegate.table[row][col] = Nonogram::CELL_BLACK;
		[self redrawAndNotifyDelegate];
	}
}


// Place (0, 0) at top left corner of view
- (BOOL)isFlipped {
	return YES;
}

@end
