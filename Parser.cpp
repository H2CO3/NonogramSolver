//
// Parser.cpp
// Parsing and serializing nonogram constraints and images as strings
//
// Created by Olívia Kozák and Réka Tóth on 27/12/2014
//

#include "Parser.hpp"


bool Parser::lex(std::string src) {
	cursor = 0;
	tokens = {};

	for (auto it = src.cbegin(); it != src.cend();) {
		// skip any whitespace
		while (it != src.cend() and std::isspace(*it)) {
			it++;
		}

		// lex '{' or '}'
		if (*it == '{' or *it == '}') {
			auto start = it++;
			tokens.push_back(std::string(start, it));
			continue;
		}

		// lex numbers
		if (std::isdigit(*it)) {
			auto start = it;
			do {
				it++;
			} while (it != src.cend() and std::isdigit(*it));

			tokens.push_back(std::string(start, it));
			continue;
		}

		// Any other character is an error
		return false;
	}

	return true;
}

bool Parser::accept(std::string token) {
	if (not eof() and tokens[cursor] == token) {
		cursor++;
		return true;
	}

	return false;
}

Parser::Maybe<std::string> Parser::acceptNumber() {
	if (not eof() and std::isdigit(tokens[cursor][0])) {
		return tokens[cursor++];
	}

	return {};
}

Parser::AST<std::vector<int>> Parser::parseNumList() {
	if (not accept("{")) {
		return {};
	}

	std::vector<int> numList;

	while (not eof() and not at("}")) {
		if (auto token = acceptNumber()) {
			try {
				numList.push_back(std::stoi(token.value));
			} catch (std::exception) {
				// error: couldn't convert string to integer
				return {};
			}
		} else {
			return {};
		}
	}

	if (not accept("}")) {
		return {};
	}

	// Filter out potential zero value (meaning empty line).
	// Note that the zero can only exist if
	// it is the _only_ entry in a number list.
	// If the list contains more than one elements,
	// then neither of them is permitted to be zero.
	if (numList.size() == 1 and numList[0] == 0) {
		numList = {};
	} else if (std::any_of(numList.begin(), numList.end(), [=](int num) {
		return num == 0;
	})) {
		return {};
	}

	return numList;
}

Parser::AST<std::vector<std::vector<int>>>
Parser::parseConstraintList(std::string src) {
	if (not lex(src)) {
		return {};
	}

	if (not accept("{")) {
		return {};
	}

	std::vector<std::vector<int>> result;

	while (not eof() and not at("}")) {
		auto constraint = parseNumList();
		if (not constraint) {
			return {};
		}

		result.push_back(constraint.value);
	}

	if (not accept("}")) {
		return {};
	}

	// must have reached eof by now
	if (not eof()) {
		return {};
	}

	return result;
}

Parser::AST<Nonogram::Constraints> Parser::parseConstraints(std::string src) {
	std::stringstream ss(src);
	std::string line;

	// Read number of columns and rows
	// (they are two base-10 integers separated by WS)
	if (not std::getline(ss, line)) {
		return {};
	}

	std::size_t cols, rows;
	try {
		std::size_t pos;
		cols = std::stoi(line, &pos, 10);
		rows = std::stoi(line.substr(pos), nullptr, 10);
	} catch (const std::exception &e) {
		return {};
	}

	// Parse constraints for rows...
	if (not std::getline(ss, line)) {
		return {};
	}
	auto rowConstraints = parseConstraintList(line);

	// ...and for columns as well
	if (not std::getline(ss, line)) {
		return {};
	}
	auto colConstraints = parseConstraintList(line);

	if (not rowConstraints or not colConstraints) {
		return {};
	}

	// sanity check for inconsistent file format
	if (rowConstraints.value.size() != rows or colConstraints.value.size() != cols) {
		return {};
	}

	// Everything's fine, return AST
	return { { rowConstraints.value, colConstraints.value } };
}

Parser::Maybe<Nonogram::Table> Parser::parseImage(std::string s) {
	Nonogram::Table result;
	std::stringstream ss(s);

	std::string line;
	while (std::getline(ss, line)) {
		try {
			auto row = _map(line, [=](char ch) {
				switch (ch) {
				case '.': return Nonogram::CELL_WHITE;
				case '*': return Nonogram::CELL_BLACK;
				default: throw std::runtime_error("invalid character");
				}
			});

			result.push_back(row);
		} catch (const std::exception &e) {
			return {};
		}
	}

	// ensure all rows have the same length
	if (result.size() < 2) {
		return result;
	}

	std::size_t cols = result.front().size();
	if (std::all_of(result.begin() + 1, result.end(), [=](const std::vector<Nonogram::Cell> &row) {
		return row.size() == cols;
	})) {
		return result;
	}

	return {};
}

std::string Parser::serializeImage(const Nonogram::Table &table) {
	std::string str;

	for (const auto &row : table) {
		for (auto cell : row) {
			assert(cell != Nonogram::CELL_UNKNOWN);
			str += cell == Nonogram::CELL_BLACK ? '*' : '.';
		}
		str += '\n';
	}

	return str;
}

std::string Parser::serializeConstraints(const Nonogram::Constraints &c) {
	auto n_rows = std::to_string(c.rows.size());
	auto n_cols = std::to_string(c.cols.size());

	auto serializeClues = [=](const std::vector<int> &v) {
		auto strings = _map(v, [=](int n) { return std::to_string(n); });

		// The format specification says that an empty row/column
		// must be represented as "{ 0 }" instead of "{}".
		// BUT WHY?!
		if (strings.empty()) {
			strings = { "0" };
		}

		return std::string("{ ") + join(strings, " ") + " }";
	};

	auto rows = _map(c.rows, serializeClues);
	auto cols = _map(c.cols, serializeClues);

	auto result = std::string("{ ") + join(rows, " ") + " }\n";
	result     += std::string("{ ") + join(cols, " ") + " }\n";

	return n_cols + ' ' + n_rows + '\n' + result;
}
