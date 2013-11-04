module std.performance.conv;

import std.traitsExt : isOneOf;


T to(T : string, S)(S val)
	if(isOneOf!(S, byte, short, int, long/*, cent*/))
{
	return toStringBody(cast(long)val);
}

T to(T : string, S)(S val)
	if (isOneOf!(S, ubyte, ushort, uint, ulong/*, ucent*/))
{
	return toStringBody(cast(ulong)val);
}

private:

string toStringBody(long val) @safe pure
{
	enum Min = short.min;
	enum Max = short.max;
	if (val < Min || val > Max)
	{
		static import std.conv;
		
		return std.conv.to!string(val);
	}
	else
	{
		import std.performance.conv_integer_string_tables;
		// If CTFE becomes a lot more effecient, and it is plausible to
		// generate the table at compile time, do it.
		//static immutable string[Max - Min + 1] conversionTable = () {
		//	string[Max - Min + 1] ret;
		//	foreach (i; Min..Max + 1)
		//	{
		//		ret[i + (0 - Min)] = std.conv.to!string(i);
		//	}
		//	return ret;
		//}();
		return signedStringConversionTable[cast(short)val + (0 - Min)];
	}
}

string toStringBody(ulong val) @safe pure
{
	enum Min = ushort.min;
	enum Max = ushort.max;
	if (val < Min || val > Max)
	{
		static import std.conv;
		
		return std.conv.to!string(val);
	}
	else
	{
		import std.performance.conv_integer_string_tables;
		// If CTFE becomes a lot more effecient, and it is plausible to
		// generate the table at compile time, do it.
		//static immutable string[Max - Min + 1] conversionTable = () {
		//	string[Max - Min + 1] ret;
		//	foreach (i; Min..Max + 1)
		//	{
		//		ret[i + (0 - Min)] = std.conv.to!string(i);
		//	}
		//	return ret;
		//}();
		return unsignedStringConversionTable[cast(short)val + (0 - Min)];
	}
}