//
// Nonogram.hpp
// Abstract nonogram representation
//
// Created by Arpad Goretity
// on 27/12/2014
//
// Inspired by the Nonogram example in the Gecode source distribution
//


#ifndef NONOGRAM_NONOGRAM_HPP
#define NONOGRAM_NONOGRAM_HPP

#include <vector>
#include <memory>
#include <unordered_map>
#include <mutex>

#include <gecode/int.hh>
#include <gecode/minimodel.hh>
#include <gecode/search.hh>

#include "Support.hpp"

class Nonogram : public Gecode::Space {
public:
	enum Cell: unsigned char {
		CELL_WHITE = 0,
		CELL_BLACK = 1,
		CELL_UNKNOWN = Cell(-1)
	};

	struct Constraints {
		std::vector<std::vector<int>> rows;
		std::vector<std::vector<int>> cols;
	};

	// This is what we use to describe and return a particular solution
	typedef std::vector<std::vector<Cell>> Table;

protected:
	// steps is a lookup table from a pointer as key to a vector of
	// nonogram configurations. The vector of nonogram configurations
	// represents the states of the individual steps the solver goes
	// through. The key is a pointer to a vector of such vectors of
	// configurations; it is supplied by the user and it is non-nullptr
	// if the user wants to get the steps from the solver. The key
	// always corresponds to the steps of one particular solution.
	// Protecting the map with a mutex is required since the solver
	// is multi-threaded.
	static std::mutex steps_mutex;
	static std::unordered_map<void *, std::vector<Table> *> steps;

	Constraints constraints;        // Specification of the puzzle
	Gecode::BoolVarArray cellArray; // pseudo-2D array of variables
	                                // in row major format

	void *key;

	static Gecode::REG buildRegexForLine(std::vector<int> blockSizes);

	// This returns the state of each cell (i. e. the solution
	// itself) in row major format, so that it's easier to print.
	// Each cell is represented as an unsigned char:
	// 0 = white, 1 = black, -1 = unknown).
	Table getState() const;

public:

	// Convert table configuration into its matching constraint set
	static Constraints constraintsFromTable(const Table &t);

	inline std::size_t rows() const { return constraints.rows.size(); }
	inline std::size_t cols() const { return constraints.cols.size(); }

	// User-friendly constructor
	Nonogram(const Constraints &c);

	// Required, machine-friendly constructor
	Nonogram(bool isShared, Nonogram &that);

	// Another, required method for cloning the object in a different manner
	inline Space *copy(bool isShared) {
		return new Nonogram(isShared, *this);
	}

	// nSolutions is the maximal number of solutions to be returned.
	// 'steps' is either nullptr, or it should point to a vector of
	//  vector of tables. It will be filled with the state of the
	//  table for each heuristic branching step for each solution.
	std::vector<Table> solve(std::size_t nSolutions = 1, std::vector<std::vector<Table>> *outSteps = nullptr);
};

#endif // NONOGRAM_NONOGRAM_HPP
