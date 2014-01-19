module std.performance.string;

// TODO: Unittest.
bool contains(char c)(scope string str) @trusted pure nothrow
{
	//if (__ctfe)
	{
		foreach (char cc; str)
		{
			if (cc == c)
				return true;
		}
		return false;
	}

//	static size_t genSearchValue(char c)
//	{
//		size_t ret = c;
//		for (auto i = 0; i < size_t.sizeof; i++)
//		{
//			ret <<= 8;
//			ret |= c;
//		}
//		return ret;
//	}
//	enum size_t searchValue = genSearchValue(c);
//
//	size_t* val = cast(size_t*)str.ptr;
//	size_t* valEnd = &val[str.length / size_t.sizeof];
//	while (val < valEnd)
//	{
//		if (*val == searchValue)
//			return true;
//		val++;
//	}
//	for (auto i = str.length % size_t.sizeof; i < str.length; i++)
//	{
//		if (str[i] == c)
//			return true;
//	}
//	return false;
}

// TODO: Check if this gets properly marked as nothrow for the runtime version.
bool equal(string other, bool caseSensitive = true)(scope string value) @trusted pure
{
	if (__ctfe)
	{
		static if (caseSensitive)
			return value == other;
		else
		{
			import std.string : toLower;

			// Alas, this makes it so I can't explicitly mark this method as nothrow.
			// TODO: Find a way to still be able to explicitly mark this as nothrow.
			return value.toLower() == other.toLower();
		}
	}

	if (value.length != other.length)
		return false;

	static if (caseSensitive)
	{
		import std.c.string : memcmp;

		return !memcmp(other.ptr, value.ptr, other.length);
	}
	else
	{
		static bool staticEach(string a, int i)(string str)
		{
			import std.ascii : toLower, toUpper;

			if (str[i] != a[0].toUpper() && str[i] != a[0].toLower())
				return false;

			static if (a.length == 1)
				return true;
			else
				return staticEach!(a[1..$], i + 1)(str);
		}
		return staticEach!(other, 0)(value);
	}
}
unittest
{
	import std.testing : assertStaticAndRuntime;

	assertStaticAndRuntime!("hello".equal!("hello"));
	assertStaticAndRuntime!(!"Hello".equal!("hello"));
	assertStaticAndRuntime!(!"hello there!".equal!("hello"));

	assertStaticAndRuntime!("hello".equal!("hello", false));
	assertStaticAndRuntime!("Hello".equal!("hello", false));
	assertStaticAndRuntime!(!"Hello There!".equal!("hello", false));
}
