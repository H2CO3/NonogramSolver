//
// Support.hpp
// (Mainly) functional-style utilities
//
// Created by Arpad Goretity on 24/12/2014
// Licensed under the 3-clause BSD License
//

/////////////////////////////////////////////////////////////////
// C++ doesn't have these FUNCTIONAL-STYLE FUNCTIONS in style. //
// What a shame! (and iterators suck, value semantics rocks!)  //
/////////////////////////////////////////////////////////////////


#ifndef NONOGRAM_SUPPORT_HPP
#define NONOGRAM_SUPPORT_HPP

#include <vector>
#include <string>
#include <algorithm>
#include <iterator>
#include <numeric>


template<typename T, template<typename... Types> class C, typename... Types>
T sum(const C<Types...> &v)
{
	return std::accumulate(v.begin(), v.end(), T(0));
}

template<typename T, typename F, template<typename U, typename... Types> class C, typename... Types>
std::vector<typename std::result_of<F(T)>::type> _map(const C<T, Types...> &v, F fn)
{
	std::vector<typename std::result_of<F(T)>::type> result(v.size());
	std::transform(v.begin(), v.end(), result.begin(), fn);
	return result;
}

template<typename F, template<typename... Types> class C, typename... Types>
C<Types...> filter(const C<Types...> &v, F fn)
{
	C<Types...> result;

	for (const auto &elem : v) {
		if (fn(elem)) {
			result.push_back(elem);
		}
	}

	return result;
}

static std::string join(const std::vector<std::string> &v, std::string delim)
{
	if (v.size() < 2) {
		return v.size() ? v[0] : "";
	}

	std::string s = v[0];

	for (auto it = v.cbegin() + 1; it != v.end(); it++) {
		s += delim + *it;
	}

	return s;
}

#endif // NONOGRAM_SUPPORT_HPP
