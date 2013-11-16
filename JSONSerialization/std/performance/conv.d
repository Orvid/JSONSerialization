module std.performance.conv;

import std.ascii : LetterCase;
import std.conv : ConvException, unsigned;
import std.exception : enforce;
import std.range : ElementEncodingType, isOutputRange;
import std.traits : isIntegral, isSomeString, Select, Unqual, Unsigned;
import std.traitsExt : Dequal;

T to(T, S)(S value) @trusted pure nothrow
	if (is(Dequal!T == Dequal!S))
{
	return cast(T)value;
}

T to(T, S)(S value)
	if (!is(Dequal!T == Dequal!S))
{
	import std.conv : to;

	return to!T(value);
}

T parse(T, S)(S s) @safe pure
	if (isIntegral!T && isSomeString!S)
{
	static if (size_t.sizeof == 8)
	{
		alias NativeInteger = long;
		alias NativeUInteger = ulong;
	}
	else // 32-bit and unknown.
	{
		alias NativeInteger = int;
		alias NativeUInteger = uint;
	}

	static if (T.sizeof < NativeInteger.sizeof)
	{
		// smaller types are handled like integers
		auto v = .parse!(Select!(T.min < 0, NativeInteger, NativeUInteger))(s);
		auto result = () @trusted { return cast(T)v; }();
		if (result != v)
			throw new Exception("Failed to parse the string!");
		return result;
	}
	else
	{
		// An native integer or larger.
		
		static if (T.min < 0)
			bool sign = false;
		else
			enum sign = false;
		T v = 0;
		bool atStart = true;
		// This is true regardless of the size of the integer.
		enum char maxLastDigit = T.min < 0 ? '7' : '5';
		while (s.length)
		{
			switch (s[0])
			{
				case '0': .. case '9':
					if (v >= T.max/10 && (v != T.max/10 || s[0] - sign > maxLastDigit))
						throw new Exception("The number overflowed!");
					v = cast(T)(v * 10 + (s[0] - '0'));
					atStart = false;
					break;

				static if (T.min < 0)
				{
					case '+':
						if (!atStart)
							throw new Exception("Invalid character!");
						break;
					case '-':
						if (atStart)
							sign = true;
						else
							throw new Exception("Invalid character!");
						break;
				}
				default:
					throw new Exception("Invalid character!");
			}
			s = s[1..$];
		}
		if (atStart)
			throw new Exception("Failed to parse the string!");
		static if (T.min < 0)
		{
			if (sign)
			{
				v = -v;
			}
		}
		return v;
	}
}

void to(T, S, OR)(S value, OR outputRange, uint radix = 10, LetterCase letterCase = LetterCase.upper) @trusted pure
	if (isIntegral!S && isSomeString!T && !is(T == enum) && isOutputRange!(OR, T))
in
{
	assert(radix >= 2 && radix <= 36);
}
body
{
	alias EEType = Unqual!(ElementEncodingType!T);
	// This is the maximum size of the smallest radix.
	EEType[S.sizeof * 8] buffer = void;
	
	void toStringRadixConvert(uint radix = 0, bool neg = false)(uint runtimeRadix = 0)
	{
		static if (neg)
			ulong div = void, mValue = unsigned(-value);
		else
			Unsigned!(Unqual!S) div = void, mValue = unsigned(value);
		
		size_t index = buffer.length;
		char baseChar = letterCase == LetterCase.lower ? 'a' : 'A';
		char mod = void;
		
		do
		{
			static if (radix == 0)
			{
				div = cast(S)(mValue / runtimeRadix );
				mod = cast(ubyte)(mValue % runtimeRadix);
				mod += mod < 10 ? '0' : baseChar - 10;
			}
			else static if (radix > 10)
			{
				div = cast(S)(mValue / radix );
				mod = cast(ubyte)(mValue % radix);
				mod += mod < 10 ? '0' : baseChar - 10;
			}
			else
			{
				div = cast(S)(mValue / radix);
				mod = mValue % radix + '0';
			}
			buffer[--index] = cast(char)mod;
			mValue = div;
		} while (mValue);
		
		static if (neg)
		{
			buffer[--index] = '-';
		}
		outputRange.put(cast(T)buffer[index..$]);
	}
	
	enforce(radix >= 2 && radix <= 36, new ConvException("Radix error"));
	
	switch(radix)
	{
		case 2:
			toStringRadixConvert!2();
			break;
		case 8:
			toStringRadixConvert!8();
			break;
		case 10:
			if (value < 0)
				toStringRadixConvert!(10, true)();
			else
				toStringRadixConvert!10();
			break;
		case 16:
			toStringRadixConvert!16();
			break;
		default:
			toStringRadixConvert(radix);
			break;
	}
}