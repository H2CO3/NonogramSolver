//
// Classifier.hpp
// Difficulty classification helpers
//
// Created by Arpad Goretity on 26/12/2014
// Licensed under the 3-clause BSD License
//

#ifndef NONOGRAM_CLASSIFIER_HPP
#define NONOGRAM_CLASSIFIER_HPP

#include "Nonogram.hpp"

std::vector<std::vector<std::vector<Nonogram::Cell>>>
configsForAllLines(
	int lineLength,
	const std::vector<std::vector<int>> &blockSizes,
	int maxNumOfConfigsPerLine
);

#endif // NONOGRAM_CLASSIFIER_HPP
