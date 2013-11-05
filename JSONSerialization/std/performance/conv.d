module std.performance.conv;

import std.ascii : LetterCase;
import std.conv : ConvException, unsigned;
import std.exception : enforce;
import std.range : ElementEncodingType, isOutputRange;
import std.traits : isIntegral, isSomeString, Unqual, Unsigned;
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