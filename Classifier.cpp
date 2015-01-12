//
// Classifier.cpp
// Difficulty classification helpers
//
// Created by Arpad Goretity on 26/12/2014
// Licensed under the 3-clause BSD License
//


#include "Classifier.hpp"
#include "Support.hpp"

#include <vector>
#include <thread>
#include <future>
#include <cassert>

// Generates all possible states (black/white) for a line of 'total' cells
// using combinations with repetition. Pseudo-Haskell follows:
//
//    combinations(total_length, selected)
//       | _ 0       -> STATE_WHITE repeated total_length times
//       | 0 _       -> empty array
//       | otherwise -> combinations(total_length - 1, selected - 1) // Head selected, remaining 'selected - 1'
//                                                                   // cells to select; concatted with...
//                      ++ combinations(total_length - 1, selected)  // Head is not selected
//
// 'selected' is the number of contiguous black blocks in the sequence
// 'blockSizes' contains the length of each such block in turn.
// 'blockSizeIndex' is used to select the appropriate next block size
// from the blockSizes array when calling rowConfigs recursively.
static
std::vector<std::vector<Nonogram::Cell>>
lineConfigs(int total, int selected, const std::vector<int> &blockSizes, int blockSizeIndex, int maxNumOfConfigsPerLine)
{
	if (selected == 0) {
		return { std::vector<Nonogram::Cell>(total) };
	}

	if (total == 0) {
		return {};
	}

	auto selectedConfigs = lineConfigs(total - 1, selected - 1, blockSizes, blockSizeIndex + 1, maxNumOfConfigsPerLine);
	auto subSelected = _map(selectedConfigs, [=](std::vector<Nonogram::Cell> seq) {
		std::vector<Nonogram::Cell> allBlack(blockSizes[blockSizeIndex], Nonogram::CELL_BLACK);
		seq.insert(seq.begin(), allBlack.begin(), allBlack.end());
		return seq;
	});

	if (subSelected.size() > maxNumOfConfigsPerLine) {
		return subSelected;
	}

	auto unselectedConfigs = lineConfigs(total - 1, selected, blockSizes, blockSizeIndex, maxNumOfConfigsPerLine);
	auto subUnselected = _map(unselectedConfigs, [=](std::vector<Nonogram::Cell> seq) {
		seq.insert(seq.begin(), Nonogram::CELL_WHITE);
		return seq;
	});

	subSelected.insert(subSelected.end(), subUnselected.begin(), subUnselected.end());
	return subSelected;
}

// This filters out only the row configurations that satisfy the clues
// A 'line' is either a row or a column of the puzzle.
static
std::vector<std::vector<Nonogram::Cell>>
possibleLineConfigs(int lineLength, const std::vector<int> &blocks, int maxNumOfConfigsPerLine)
{
	// n is the number of black BLOCKS
	int n = blocks.size();

	// F is the number of white CELLS!
	// NB, it IS NOT the number of white *blocks*. Since black cells
	// need to stay together in blocks, but contiguous white areas do NOT
	// have a pre-defined, fixed length, it's easier to generate them
	// treating them as independent objects:
	// _ _ _ | BLACK BOX | _ _ | BLACK BOX | _ | BLACK BOX | _ _ _
	//         ^^^^^^^^^         ^^^^^^^^^       ^^^^^^^^^         <- 3 black blocks
	// ^ ^ ^               ^ ^               ^               ^ ^ ^ <- (3 + 2 + 1 + 3) white cells
	// The number of white cells, F is given by F = n - SUM(number of black cells)
	// So, in total, there are F + n possitions to decide the state of: 'selected' (==black)
	// or unselected (==white), and there are n blocks to select; consequently,
	// we need to generate all combinations [BINOM(F + n, n)].
	// Then, we need to get rid of the configurations where two black boxes follow
	// immediately, because that's prohibited by definition.
	int F = lineLength - sum<int>(blocks);

	auto configs = lineConfigs(F + n, n, blocks, 0, maxNumOfConfigsPerLine);

	return filter(configs, [=](const std::vector<Nonogram::Cell> &seq) {
		std::size_t i = 0;
		std::vector<int> blockSizes;

		// Count consecutive black cells
		while (i < seq.size()) {
			int consec = 0;
			while (i < seq.size() and seq[i]) {
				i++;
				consec++;
			}

			if (i > 0) {
				blockSizes.push_back(consec);
			}

			while (i < seq.size() and not seq[i]) {
				i++;
			}
		}

		if (blockSizes.size() == 0) {
			blockSizes.push_back(0);
		}

		return blockSizes == blocks;
	});
}

std::vector<std::vector<std::vector<Nonogram::Cell>>>
configsForAllLines(
	int lineLength,
	const std::vector<std::vector<int>> &blockSizes,
	int maxNumOfConfigsPerLine
)
{
	std::vector<std::future<std::vector<std::vector<Nonogram::Cell>>>> fs;

	// Launch computation of possible row configurations asynchronously
	for (const auto &lineDesc : blockSizes) {
		auto good = std::async(std::launch::async, [=]{
			return possibleLineConfigs(lineLength, lineDesc, maxNumOfConfigsPerLine); 
		});
		fs.push_back(std::move(good));
	}

	std::vector<std::vector<std::vector<Nonogram::Cell>>> result;
	// and wait for each of them to finish
	for (auto &&fut : fs) {
		result.push_back(fut.get());
	}

	return result;
}
