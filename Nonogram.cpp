//
// Nonogram.cpp
// Abstract nonogram representation
//
// Created by Arpad Goretity
// on 27/12/2014
//
// Inspired by the Nonogram example in the Gecode source distribution
//

#include "Nonogram.hpp"

std::mutex Nonogram::steps_mutex;
std::unordered_map<void *, std::vector<Nonogram::Table> *> Nonogram::steps;

Gecode::REG Nonogram::buildRegexForLine(std::vector<int> blockSizes) {
	Gecode::REG regex;

	// It's trivial to convert a block size description into
	// a regular expression:
	// there may be optional leading space before the first block
	// and/or after the last one,
	// and there needs to be at least one space between each block.
	// We represent white spaces by a '0' and black cells by a '1'.

	// These match the single integers '0' and '1'
	Gecode::REG _0(CELL_WHITE), _1(CELL_BLACK);

	regex += *_0; // zero or more empty cells; "0*"

	for (std::size_t i = 0; i < blockSizes.size(); i++) {
		if (i > 0) {
			regex += +_0; // one ore more empty cells between blocks; "0+"
		}

		// ...and then exactly blockSizes[i] pieces of consecutive black cells
		// (the '()' operator takes the minimal and maximal number of repeats;
		// this is equivalent with "1{N,N}" where N is blockSizes[i].)
		regex += _1(blockSizes[i], blockSizes[i]);
	}

	regex += *_0; // and the last cells may be empty too

	return regex;
}

Nonogram::Table Nonogram::getState() const {
	std::vector<std::vector<Nonogram::Cell>> table(
		this->rows(),
		std::vector<Nonogram::Cell>(this->cols())
	);

	for (std::size_t i = 0; i < this->rows(); i++) {
		for (std::size_t j = 0; j < this->cols(); j++) {
			const auto &var = cellArray[i * this->cols() + j];
			table[i][j] = var.assigned() ? Cell(var.val()) : Nonogram::CELL_UNKNOWN;
		}
	}

	return table;
}

Nonogram::Constraints Nonogram::constraintsFromTable(const Nonogram::Table &t) {
	auto constraintGen = [=](const std::vector<Cell> &seq) {
		std::vector<int> blockSizes;

		std::size_t i = 0;
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

		return blockSizes;
	};


	// for each row...
	auto rowConstraints = _map(t, constraintGen);

	// ...and column
	std::vector<std::vector<int>> colConstraints;
	for (std::size_t i = 0; i < (t.size() ? t[0].size() : 0); i++) {
		auto ith_col = _map(t, [=](const std::vector<Cell> &row) {
			return row[i];
		});

		colConstraints.push_back(constraintGen(ith_col));
	}

	return { rowConstraints, colConstraints };
}

Nonogram::Nonogram(const Nonogram::Constraints &c) :
	constraints(c),
	cellArray(
		*this,
		this->rows() * this->cols(),
		0,
		1
	)
{
	// Add regular expression constraints to lines
	// in both dimensions (rows and columns)
	// In order to extract the rows and columns from
	// our 2D array, we use a Matrix.
	Gecode::Matrix<Gecode::BoolVarArray> helperMat(cellArray, this->cols(), this->rows());

	// Rows
	for (std::size_t i = 0; i < this->rows(); i++) {
		auto regexForRow = buildRegexForLine(constraints.rows[i]);
		Gecode::extensional(*this, helperMat.row(i), regexForRow);
	}

	// Columns
	for (std::size_t i = 0; i < this->cols(); i++) {
		auto regexForCol = buildRegexForLine(constraints.cols[i]);
		Gecode::extensional(*this, helperMat.col(i), regexForCol);
	}

	// while performing Depth-First Search, select child nodes
	// based on their Accumulated Failure Count (AFC)
	branch(*this, cellArray, Gecode::INT_VAR_AFC_MAX(1.0), Gecode::INT_VAL_MAX());
}

Nonogram::Nonogram(bool isShared, Nonogram::Nonogram &that) :
	Space(isShared, that),
	constraints(that.constraints),
	key(that.key)
{
	cellArray.update(*this, isShared, that.cellArray);

	std::lock_guard<std::mutex> lock(steps_mutex);

	if (steps[key]) {
		steps[key]->push_back(getState());
	}
}

std::vector<Nonogram::Table> Nonogram::solve(std::size_t nSolutions, std::vector<std::vector<Table>> *outSteps) {
	key = outSteps;

	// Create depth-first search solver engine
	Gecode::DFS<Nonogram> solverEngine(this);

	// The results are accumulated in this array.
	std::vector<Nonogram::Table> results;

	for (std::size_t i = 0; i < nSolutions; i++) {
		{
			std::lock_guard<std::mutex> lock(steps_mutex);

			if (outSteps) {
				outSteps->push_back({});
				steps[key] = &outSteps->back();
			}
		}

		// The pointer returned by DFS::next() is owning; it needs to be delete'd.
		// We do this more safely using a smart pointer.
		auto solution = std::unique_ptr<Nonogram>(solverEngine.next());

		// DFS::next() returns nullptr when there are no more solutions
		if (solution) {
			results.push_back(solution->getState());
		} else {
			break;
		}

	}

	// Clean up after ourselves: if we left the potentially invalidated
	// pointer to the elements of the outSteps vector, we would have a
	// dangling pointer, and next time we would try to access the
	// -- erroneously non-null -- pointer, the solver could crash...
	steps[key] = nullptr;
	return results;
}
