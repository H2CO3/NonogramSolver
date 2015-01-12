//
//  AppDelegate.mm
//  NonogramSolver
//
//  Created by Árpád Goretity on 29/12/14.
//  Copyright (c) 2014 H2CO3. All rights reserved.
//

#import "AppDelegate.hpp"
#import "NonogramView.hpp"
#import "Parser.hpp"
#import "Classifier.hpp"

#import "GCDTimer.h"

#include <fstream>
#include <string>
#include <sstream>
#include <unordered_map>


enum NonogramDifficulty {
	DIFFICULTY_TRIVIAL,
	DIFFICULTY_HEURISTIC,
	DIFFICULTY_EXPONENTIAL
};

@interface AppDelegate () <NonogramViewDelegate> {
	Nonogram::Constraints constraints; // Constraints to solve for.
	                                   // NOT the constraints that describe
	                                   // the current configuration of the table!
	Nonogram::Table table;

	NSMenuItem *newItem;
	NSMenuItem *openItem;
	NSMenuItem *saveItem;
	NSMenuItem *solveItem;
	NSMenuItem *checkUniqueItem;
	NSMenuItem *completeToUniqueItem;
	NSMenuItem *showStepsItem;
	NSMenuItem *classifyItem;
}

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSScrollView *canvas;
@property (nonatomic, strong) NonogramView *nonogramView;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.canvas = [[NSScrollView alloc] initWithFrame:[self.window.contentView bounds]];
	self.canvas.hasVerticalScroller = YES;
	self.canvas.hasHorizontalScroller = YES;
	self.canvas.allowsMagnification = YES;
	self.nonogramView = [[NonogramView alloc] init];
	[self.window.contentView addSubview:self.canvas];
	self.window.styleMask &= ~NSResizableWindowMask;

	self.nonogramView.delegate = self;
	self.canvas.documentView = self.nonogramView;

	// Set up file access menus
	NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
	NSMenu *fileMenu = [[mainMenu itemAtIndex:1] submenu];

	[fileMenu removeAllItems];

	newItem = [[NSMenuItem alloc] initWithTitle:@"New..." action:@selector(newMenuClicked) keyEquivalent:@"n"];
	newItem.target = self;

	openItem = [[NSMenuItem alloc] initWithTitle:@"Open..." action:@selector(openMenuClicked) keyEquivalent:@"o"];
	openItem.target = self;

	saveItem = [[NSMenuItem alloc] initWithTitle:@"Save..." action:@selector(saveMenuClicked) keyEquivalent:@"s"];
	saveItem.target = self;

	solveItem = [[NSMenuItem alloc] initWithTitle:@"Solve" action:@selector(solveMenuClicked) keyEquivalent:@"r"];
	solveItem.target = self;

	checkUniqueItem = [[NSMenuItem alloc] initWithTitle:@"Check Uniqueness" action:@selector(checkUniqueMenuClicked) keyEquivalent:@"u"];
	checkUniqueItem.target = self;

	completeToUniqueItem = [[NSMenuItem alloc] initWithTitle:@"Complete to Unique" action:@selector(completeToUniqueMenuClicked) keyEquivalent:@"t"];
	completeToUniqueItem.target = self;

	showStepsItem = [[NSMenuItem alloc] initWithTitle:@"Show Steps of Solution" action:@selector(showStepsMenuClicked) keyEquivalent:@"R"];
	showStepsItem.target = self;

	classifyItem = [[NSMenuItem alloc] initWithTitle:@"Classify difficulty" action:@selector(classifyMenuClicked) keyEquivalent:@"d"];
	classifyItem.target = self;
	
	[fileMenu addItem:newItem];
	[fileMenu addItem:openItem];
	[fileMenu addItem:saveItem];
	[fileMenu addItem:solveItem];
	[fileMenu addItem:checkUniqueItem];
	[fileMenu addItem:completeToUniqueItem];
	[fileMenu addItem:showStepsItem];
	[fileMenu addItem:classifyItem];
}

// Indicate to user that the puzzle is being solved

- (void)enableMenuItems {
	newItem.action = @selector(newMenuClicked);
	openItem.action = @selector(openMenuClicked);
	saveItem.action = @selector(saveMenuClicked);
	solveItem.action = @selector(solveMenuClicked);
	checkUniqueItem.action = @selector(checkUniqueMenuClicked);
	completeToUniqueItem.action = @selector(completeToUniqueMenuClicked);
	showStepsItem.action = @selector(showStepsMenuClicked);
	classifyItem.action = @selector(classifyMenuClicked);
}

- (void)disableMenuItems {
	newItem.action = NULL;
	openItem.action = NULL;
	saveItem.action = NULL; // b/c of concurrency and inconsistency of 'table'
	solveItem.action = NULL;
	checkUniqueItem.action = NULL;
	completeToUniqueItem.action = NULL; // also that ^^
	showStepsItem.action = NULL;
	classifyItem.action = NULL;
}

- (NSTextField *)textLabelWithFrame:(NSRect)f text:(NSString *)text {
	NSTextField *textField = [[NSTextField alloc] initWithFrame:f];
	textField.stringValue = text;
	textField.bezeled = NO;
	textField.drawsBackground = NO;
	textField.editable = NO;
	textField.selectable = NO;
	return textField;
}

- (BOOL)askUserToReallyOpenHugePuzzleOfRows:(std::size_t)rows columns:(std::size_t)cols {
	NSAlert *alert = [NSAlert alertWithMessageText:@"Huge table size"
									 defaultButton:@"Cancel"
								   alternateButton:@"OK"
									   otherButton:nil
						 informativeTextWithFormat:@"A %zu x %zu table contains %zu cells. "
							  "This may consume too much memory, be impractically slow to solve, "
							  "and it may render your computer unresponsive. Proceed anyway?",
							  rows, cols, rows * cols];
	alert.alertStyle = NSWarningAlertStyle;
	return [alert runModal] == NSAlertDefaultReturn;
}

- (void)runNumberOfSolutionsAlert:(std::size_t)size {
	NSString *solutionMessage;

	switch (size) {
	case 0:  solutionMessage = @"No solution exists"; break;
	case 1:  solutionMessage = @"The solution is unique"; break;
	default: solutionMessage = @"More than one solution exists"; break;
	}

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = @"Search for solutions finished";
	alert.informativeText = solutionMessage;
	[alert runModal];
}

- (void)newMenuClicked {
	NSAlert *alert = [NSAlert alertWithMessageText:@"Draw new image"
	                                 defaultButton:@"OK"
	                               alternateButton:@"Cancel"
	                                   otherButton:nil
	                     informativeTextWithFormat:@""];

	NSTextField *rowsTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 60, 24)];
	rowsTextField.stringValue = @"10";
	NSTextField *colsTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(130, 0, 60, 24)];
	colsTextField.stringValue = @"15";

	NSTextField *sep1 = [self textLabelWithFrame:NSMakeRect(70, 0, 60, 22) text:@"rows by"];
	NSTextField *sep2 = [self textLabelWithFrame:NSMakeRect(200, 0, 60, 22) text:@"columns"];
	
	NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
	[accessoryView addSubview:rowsTextField];
	[accessoryView addSubview:colsTextField];
	[accessoryView addSubview:sep1];
	[accessoryView addSubview:sep2];
	[alert setAccessoryView:accessoryView];

	NSInteger button = [alert runModal];
	if (button == NSAlertDefaultReturn) {
		int rows = rowsTextField.stringValue.intValue;
		int cols = colsTextField.stringValue.intValue;

		if (rows < 0) {
			rows = 0;
		}

		if (cols < 0) {
			cols = 0;
		}

		// Handle exceptionally big nonograms
		if (cols * rows > 5000 or cols > 5000 or rows > 5000) {
			if ([self askUserToReallyOpenHugePuzzleOfRows:rows columns:cols]) {
				// YES: the user cancelled
				return;
			}
		}

		table = Nonogram::Table(rows, std::vector<Nonogram::Cell>(cols, Nonogram::CELL_WHITE));
		[self.nonogramView reload];
	}
}

- (void)openMenuClicked {
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.canChooseDirectories = NO;
	panel.allowsMultipleSelection = NO;
	panel.allowedFileTypes = @[@"constraint", @"table"];

	[panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) {
			return;
		}

		NSArray *urls = panel.URLs;
		NSString *path = [urls[0] path];
		NSString *extension = path.pathExtension;

		auto runFileFormatCorruptedDialog = []{
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"File corrupted";
			alert.informativeText = @"The file could not be parsed because its format is incorrect.";
			[alert runModal];
		};

		static std::unordered_map<std::string, std::function<void(const std::string &)>> actionsByExtension {
			{
				"constraint",
				[=](const std::string &src) {
					Parser parser;
					auto maybeConstraints = parser.parseConstraints(src);
					if (maybeConstraints) {
						constraints = maybeConstraints.value;
						std::size_t rows = constraints.rows.size();
						std::size_t cols = constraints.cols.size();

						// Handle exceptionally huge puzzles
						if (cols * rows > 5000 or rows > 5000 or cols > 5000) {
							if ([self askUserToReallyOpenHugePuzzleOfRows:rows columns:cols]) {
								// YES: the user cancelled
								return;
							}
						}

						[self.nonogramView reload];
					} else {
						runFileFormatCorruptedDialog();
					}
				},
			},
			{
				"table",
				[=](const std::string &src) {
					Parser parser;
					auto maybeTable = parser.parseImage(src);
					if (maybeTable) {
						// Handle exceptionally big nonograms
						std::size_t rows = maybeTable.value.size();
						std::size_t cols = rows ? maybeTable.value[0].size() : 0;

						if (cols * rows > 5000 or cols > 5000 or rows > 5000) {
							if ([self askUserToReallyOpenHugePuzzleOfRows:rows columns:cols]) {
								// YES: the user cancelled
								return;
							}
						}

						table = maybeTable.value;
						[self.nonogramView reload];
					} else {
						runFileFormatCorruptedDialog();
					}
				}
			}
		};

		// Wrap all the things in dispatch_async(), so that
		// the modal NSOpenPanel can close itself
		auto action = actionsByExtension[extension.UTF8String];
		assert(action);
		dispatch_async(dispatch_get_main_queue(), ^() {
			// read file into buffer and call appropriate action
			std::ifstream f(path.UTF8String);
			std::stringstream ss;
			ss << f.rdbuf();
			action(ss.str());
		});
	}];
}

- (void)saveMenuClicked {
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.canCreateDirectories = YES;
	savePanel.extensionHidden = NO;
	savePanel.allowedFileTypes = @[@"constraint", @"table"];

	[savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) {
			return;
		}

		NSString *filePath = savePanel.URL.path;
		NSString *extension = filePath.pathExtension;

		std::unordered_map<std::string, std::function<void(std::string)>> saveActions {
			{
				// Save the constraints inferred from the
				// current configuration of the table
				"constraint",
				[=](std::string fname) {
					Parser parser;
					std::ofstream f(fname);
					auto localConstr = Nonogram::constraintsFromTable(self.table);
					f << parser.serializeConstraints(localConstr);
				}
			},
			{
				// Save the current configuration of the table itself
				"table",
				[=](std::string fname) {
					Parser parser;
					std::ofstream f(fname);
					f << parser.serializeImage(table);
				}
			}
		};

		saveActions[extension.UTF8String](filePath.UTF8String);
	}];
}

- (void)checkUniqueMenuClicked {
	auto savedTable = table;
	table = {};

	// Start animation meaning that the computation is in progress
	[self disableMenuItems];
	[self.nonogramView startGlowAnimation];

	// solve puzzle in the background
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// search for at least 2 solutions
		// in order to decide uniqueness
		auto localConstr = Nonogram::constraintsFromTable(savedTable);
		Nonogram n(localConstr);
		auto solutions = n.solve(2);

		dispatch_async(dispatch_get_main_queue(), ^{
			[self enableMenuItems];
			[self.nonogramView stopGlowAnimation];

			// Restore state of table
			table = savedTable;
			[self.nonogramView reload];

			// Inform user of solutions
			[self runNumberOfSolutionsAlert:solutions.size()];
		});
	});
}

// Solve for current constraints
- (void)solveMenuClicked {
	// prevent user from messing with stuff
	table = {};

	[self disableMenuItems];
	[self.nonogramView startGlowAnimation];

	// solve puzzle in the background
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		Nonogram n(constraints);

		// search for at least 2 solutions
		// in order to decide uniqueness
		auto solutions = n.solve(2);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self enableMenuItems];
			[self.nonogramView stopGlowAnimation];

			if (solutions.size()) {
				// if solutions is not empty, we've got a solution
				table = solutions[0];
			} else {
				table = {};
			}

			[self.nonogramView reload];

			// Inform user of solutions
			[self runNumberOfSolutionsAlert:solutions.size()];
		});
	});
}

- (void)completeToUniqueMenuClicked {
	[self disableMenuItems];

	// don't let the user tamper with the board
	self.nonogramView.interactionEnabled = NO;

	// The method:
	// Search for two different solutions:
	// - if there's only one, we are done.
	// - else select the cells that are black in one solution
	//   and keep incrementally adding black cells from the other one,
	//   until a unique solution is found.

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		auto solutions = Nonogram(Nonogram::constraintsFromTable(table)).solve(2);

		while (solutions.size() > 1) {
			auto next = solutions[0];
			bool foundBlackCell = false;

			for (std::size_t i = 0; i < next.size(); i++) {
				if (foundBlackCell) {
					break;
				}

				for (std::size_t j = 0; j < next[i].size(); j++) {
					if (next[i][j] == Nonogram::CELL_WHITE and solutions[1][i][j] == Nonogram::CELL_BLACK) {
						next[i][j] = Nonogram::CELL_BLACK;
						foundBlackCell = true;
						break;
					}
				}
			}

			// Live update!
			dispatch_async(dispatch_get_main_queue(), ^{
				table = next;
				[self.nonogramView reload];
			});

			solutions = Nonogram(Nonogram::constraintsFromTable(next)).solve(2);
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			[self enableMenuItems];
			self.nonogramView.interactionEnabled = YES;

			[[NSAlert alertWithMessageText:@"Converted to unique solution"
	                                 defaultButton:@"OK"
	                               alternateButton:nil
	                                   otherButton:nil
	                     informativeTextWithFormat:@""] runModal];
		});
	});
}

// Search for only ONE solution, and show the steps
// of the heuristics working its way through the puzzle.
- (void)showStepsMenuClicked {
	// Prevent user from messing around with the table configuration
	table = {};
	[self disableMenuItems];
	[self.nonogramView startGlowAnimation];
	self.nonogramView.interactionEnabled = NO;

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		std::vector<std::vector<Nonogram::Table>> steps;
		auto solutions = Nonogram(constraints).solve(1, &steps);

		// Re-display table, but don't enable menus just yet
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.nonogramView stopGlowAnimation];

			// it's possible that there are no solutions
			if (solutions.empty()) {
				[self runNumberOfSolutionsAlert:solutions.size() /* 0 */];
				self.nonogramView.interactionEnabled = YES;
				[self enableMenuItems];
			} else {
				// If we have found a solution, then cycle through its steps
				// Try to find a sensible time interval for each frame to be shown
				// stepsForSolution can't be a reference,
				// because it would be dangling inside the block
				auto stepsForSolution = steps[0];
				double interval = 0.5 / pow(stepsForSolution.size(), 2.0 / 3);
				__block std::size_t index = 0;
			
				__block GCDTimer *timer = [GCDTimer timerOnMainQueue];
				[timer scheduleBlock:^{
					if (index < stepsForSolution.size()) {
						// display 'index++'th frame and set timeout
						table = stepsForSolution[index++];
						[self.nonogramView reload];
					} else {
						[timer invalidate];
						[self enableMenuItems];
						table = solutions[0];
						[self.nonogramView reload];
						self.nonogramView.interactionEnabled = YES;
					}
				} afterInterval:interval repeat:YES];
			}
		});
	});
}

- (BOOL)hasUnequivocallyBlackOrWhiteCells:(const std::vector<std::vector<std::vector<Nonogram::Cell>>> &)lineConfigs lineLength:(std::size_t)lineLength {
	for (std::size_t i = 0; i < lineConfigs.size(); i++) {
		// i-th line (row or column)
		std::vector<Nonogram::Cell> surelyBlack(lineLength, Nonogram::CELL_BLACK);
		std::vector<Nonogram::Cell> surelyWhite(lineLength, Nonogram::CELL_WHITE);

		for (std::size_t j = 0; j < lineConfigs[i].size(); j++) {
			// j-th configuration
			for (std::size_t k = 0; k < lineConfigs[i][j].size(); k++) {
				// k-th cell
				if (lineConfigs[i][j][k] == Nonogram::CELL_WHITE) {
					// was white once -> cannot always be black
					surelyBlack[k] = Nonogram::CELL_WHITE;
				}
				if (lineConfigs[i][j][k] == Nonogram::CELL_BLACK) {
					// was black once -> cannot always be white
					surelyWhite[k] = Nonogram::CELL_BLACK;
				}
			}
		}

		// Found any unequivocally-black cells
		if (std::any_of(surelyBlack.begin(), surelyBlack.end(), [=](Nonogram::Cell cell) {
			return cell == Nonogram::CELL_BLACK;
		})) {
			return YES;
		}

		// Found any unequivocally-white cells
		if (std::any_of(surelyWhite.begin(), surelyWhite.end(), [=](Nonogram::Cell cell) {
			return cell == Nonogram::CELL_WHITE;
		})) {
			return YES;
		}
	}

	// Not found any unequivocally black or white rows
	return NO;
}

- (NonogramDifficulty)difficultyOfConstraints:(const Nonogram::Constraints &)c {
	// Generate all possible combinations for rows and columns
	// If both rows and columns have a unique solution on their own,
	// then the solution is trivial.
	auto rowConfigs = configsForAllLines(c.cols.size(), c.rows, 1000);
	auto colConfigs = configsForAllLines(c.rows.size(), c.cols, 1000);

	bool unique_rows = std::all_of(rowConfigs.begin(), rowConfigs.end(), [=](const std::vector<std::vector<Nonogram::Cell>> &configs) {
		return configs.size() <= 1;
	});

	bool unique_cols = std::all_of(colConfigs.begin(), colConfigs.end(), [=](const std::vector<std::vector<Nonogram::Cell>> &configs) {
		return configs.size() <= 1;
	});

	if (unique_rows and unique_cols) {
		// Trivial!
		return DIFFICULTY_TRIVIAL;
	}

	// Else, if there are cells which can be determined to be either
	// black or white by trying every possible combination, then
	// the problem can most likely be approached heuristically
	if ([self hasUnequivocallyBlackOrWhiteCells:rowConfigs lineLength:c.cols.size()]) {
		return DIFFICULTY_HEURISTIC;
	}

	if ([self hasUnequivocallyBlackOrWhiteCells:colConfigs lineLength:c.rows.size()]) {
		return DIFFICULTY_HEURISTIC;
	}

	// If there are no such cells, then state-space traversal is needed
	return DIFFICULTY_EXPONENTIAL;
}

- (void)classifyMenuClicked {
	NonogramDifficulty diff = [self difficultyOfConstraints:constraints];
	std::unordered_map<NonogramDifficulty, NSString *, std::hash<int>> diffStrings {
		{ DIFFICULTY_TRIVIAL,     @"Trivial to solve" },
		{ DIFFICULTY_HEURISTIC,   @"Efficient to solve using heuristics" },
		{ DIFFICULTY_EXPONENTIAL, @"Can only be brute-forced in O(e^n)" }
	};

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = @"Difficulty of puzzle";
	alert.informativeText = diffStrings[diff];
	[alert runModal];
}


// NonogramViewDelegate

- (Nonogram::Table &)table {
	return table;
}

- (void)nonogramViewChanged:(NonogramView *)nv {
	// may be required to do something here in the future...
}

@end
