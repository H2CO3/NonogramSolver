//
// Parser.hpp
// Parsing and serializing nonogram constraints and images as strings
//
// Created by Olívia Kozák and Réka Tóth on 27/12/2014
//

#ifndef NONOGRAM_PARSER_HPP
#define NONOGRAM_PARSER_HPP

#include <iostream>
#include <vector>
#include <string>
#include <sstream>
#include <cctype>
#include <cassert>
#include <algorithm>
#include <utility>
#include <functional>

#include "Support.hpp"
#include "Nonogram.hpp"


class Parser {
public:
	template<typename T>
	struct Maybe {
		T value;
		bool valid;

		// Nothing
		inline Maybe() : value {}, valid(false) {}

		// Just T
		inline Maybe(const T &_value) : value(_value), valid(true) {}

		inline operator bool() const { return valid; }
	};

	// AST is just a more contextful alias for Maybe
	template<typename T>
	using AST = Maybe<T>;

protected:
	std::size_t cursor;
	std::vector<std::string> tokens;

	bool lex(std::string src);

	inline bool eof() const { return not (cursor < tokens.size()); }
	inline bool at(std::string token) const { return not eof() and tokens[cursor] == token; }

	// the classic 'accept': returns true if its argument matches
	// the string at the cursor, and moves the cursor forward.
	// Returns false and doesn't touch the cursor otherwise.
	// XXX: don't forget to check for end-of-input (cursor >= tokens.size())!
	bool accept(std::string token);

	// The same thing, but accepts a number
	Maybe<std::string> acceptNumber();

	AST<std::vector<int>> parseNumList();

	// Parse all constraints for a dimension (rows/columns)
	AST<std::vector<std::vector<int>>> parseConstraintList(std::string src);

public:

	// Parses a puzzle, specified by row and column constraints
	// Trivial top-down recursive descent parser
	AST<Nonogram::Constraints> parseConstraints(std::string src);

	// Parses a solved configuration, specified by cells
	Maybe<Nonogram::Table> parseImage(std::string s);

	// Serialize a solved configuration as string
	std::string serializeImage(const Nonogram::Table &table);

	// Serialize a constraint set
	std::string serializeConstraints(const Nonogram::Constraints &c);
};

#endif // NONOGRAM_PARSER_HPP
