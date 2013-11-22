module std.serialization.bson;

import std.datetime : DateTime;
import std.range : isOutputRange;
import std.serialization : serializable, SerializationFormat;
import std.traits : ForeachType;
import std.traitsExt : isClass, isOneOf, isStruct;

final class BSONSerializationFormat : SerializationFormat
{
	template isNativeSerializationSupported(T)
	{
		static if (is(Dequal!T == T))
		{
			static if (isArray!T)
			{
				enum isNativeSerializationSupported = isNativeSerializationSupported!(ForeachType!T);
			}
			else static if (is(T == DateTime))
			{
				enum isNativeSerializationSupported = true;
			}
			else static if (isSerializable!T)
			{
				enum isNativeSerializationSupported =
					   isClass!T
					|| isStruct!T
					|| isOneOf!(T, byte, ubyte, short, ushort, int, uint, long, ulong)
					|| isOneOf!(T, double)
					|| is(T == bool)
					|| isOneOf!(T, char)
				;
			}
			else
				enum isNativeSerializationSupported = false;
		}
		else
		{
			enum isNativeSerializationSupported = false;
		}
	}

	mixin(BaseDeserializationMembers!());

	@deserializationContext private static struct BSONDeserializationContext(IR : byte[])
	{
		IR input;

		// TODO: Add a bounds checking mechanism.
		private void advance(size_t dist = 1)
		{
			input = input[dist..$];
		}

		T read(T : string)()
		{
			int len = read!int();
			string val = cast(string)input[0..len - 1];
			advance(len);
			return val;
		}

		T read(T : ubyte)()
		{
			ubyte val = input[0];
			advance();
			return val;
		}

		T read(T : int)()
		{
			version (LittleEndian)
				int val = *cast(int*)input.ptr;
			else
				static assert(0, "Need to implement this!");
			advance(4);
			return val;
		}
	}
}

void toBSON(T, OR)(T val, ref OR buf)
	if (isOutputRange!(OR, ubyte[]))
{

}

ubyte[] toBSON(T)(T val)
{
	return [];
}

T fromBSON(T)(ubyte[] data)
{
	return T.init;
}

unittest
{
	import std.testing : assertStaticAndRuntime;

	@serializable static class basicTest { string hello; }
	//assertStaticAndRuntime!(fromBSON!basicTest(cast(ubyte[])"\x16\x00\x00\x00\x02hello\x00\x06\x00\x00\x00world\x00\x00").hello == "world");
}