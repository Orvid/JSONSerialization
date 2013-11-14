module std.performance.string;

bool equal(string other, bool caseSensitive = true)(string value)
{
	if (__ctfe)
		return value == other;

	if (value.length != other.length)
		return false;

	static if (caseSensitive)
	{
		import std.c.string : memcmp;

		return !memcmp(other.ptr, value.ptr, other.length);
	}
	else
	{
		static assert(0);
	}
}