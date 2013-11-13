module std.serialization;

enum optional;
enum serializable;
enum nonSerialized;
struct serializeAs { string Name; }

import std.range : isOutputRange;
struct BinaryOutputRange(OR)
	if (isOutputRange!(OR, ubyte[]))
{
	import std.traits : isScalarType;
	import std.traitsExt : Dequal, isOneOf;

private:
	OR mInnerRange;

	// TODO: Support big endian output.
	version(BigEndian)
		static assert(0, "Support for a big-endian host still needs to be added!");

public:
	@property OR innerRange()
	{
		return mInnerRange;
	}

	this(OR init)
	{
		mInnerRange = init;
	}

	auto opDispatch(string s, Args...)(Args a) @trusted
	{
		mixin("return mInnerRange." ~ s ~ "(a);");
	}

	void put(C)(C[] arr) @trusted
		if (isScalarType!C)
	{
		mInnerRange.put(cast(ubyte[])arr);
	}

	void put(C)(C c) @trusted
		if (isScalarType!C)
	{
		if (__ctfe)
		{
			for (size_t i = 0; i < C.sizeof; i++)
				mInnerRange.put(cast(ubyte)((c >> (i * 8)) & 0xFF));
		}
		else
		{
			mInnerRange.put(cast(ubyte[])(&c)[0..C.sizeof]);
		}
	}
}
unittest
{
	import std.performance.array : Appender;
	import std.range : isOutputRange;

	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), string));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), wstring));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), dstring));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), byte[]));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), ubyte[]));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), short[]));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), ushort[]));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), int[]));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), uint[]));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), long[]));
	static assert(isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), ulong[]));
}


abstract class SerializationFormat
{
	import std.traitsExt : 
		Dequal,
		getDefaultMemberValue,
		getMemberAttribute,
		getMemberValue,
		hasAttribute,
		hasPublicDefaultConstructor,
		isClass,
		isStruct,
		isMemberField,
		memberHasAttribute
	;

protected:
	static struct SerializedFieldSet(T)
	{
		import std.performance.bitmanip : BitArray;

		alias members = membersToSerialize!T;
		// BUG: Required due to a bug that causes compilation to fail
		enum membersLength = members.length;

		mixin(genDeclarations());
		private static string genDeclarations()
		{
			import std.conv : to;
			import std.array : Appender;

			auto ret = Appender!string();

			ret.put(`BitArray!`);
			ret.put(to!string(membersLength));
			ret.put(` fieldMarkers;`);

			BitArray!membersLength expectedArr;
			foreach (i, m; members)
			{
				if (!isMemberOptional!(T, m))
					expectedArr[i] = true;
			}
			ret.put(`enum expectedFields = BitArray!`);
			ret.put(to!string(membersLength));
			ret.put(`([`);
			foreach (i, d; expectedArr.data)
			{
				if (i != 0)
					ret.put(',');
				ret.put(`0x`);
				ret.put(to!string(d, 16));
			}
			ret.put(`]);`);

			return ret.data;
		}

		@property void markSerialized(string member)() @safe pure nothrow
		{
			import std.typecons : staticIndexOf;

			fieldMarkers[staticIndexOf!(member, members)] = true;
		}

		void ensureFullySerialized() @safe pure
		{
			fieldMarkers &= expectedFields;
			if (fieldMarkers != expectedFields)
				throw new Exception("A required field was not deserialized!");
		}
	}

	enum deserializationContext;
	enum isDeserializationContext(T) = hasAttribute!(T, deserializationContext);

	template isSerializable(T)
	{
		import std.traits : isBuiltinType;

		static if (isBuiltinType!T)
			enum isSerializable = true;
		else static if (hasAttribute!(T, serializable) || is(Dequal!T == Object))
			enum isSerializable = true;
		else
			enum isSerializable = false;
	}

	static void ensurePublicConstructor(T)() @safe pure nothrow
	{
		static if (isClass!T)
			static assert(hasPublicDefaultConstructor!T, `The class '` ~ T.stringof ~ `' doesn't have a publicly visible constructor!`);
		else static if (isStruct!T)
			static assert(hasPublicDefaultConstructor!T, `The struct '` ~ T.stringof ~ `' doesn't have a publicly visible constructor!`);
		else
			static assert(0, "Not yet implemented!");
	}
	
	template membersToSerialize(T)
	{
		alias CTValSet(E...) = E;
		enum shouldSerializeMember(string member) = member != "this" && isMemberField!(T, member) && !memberHasAttribute!(T, member, nonSerialized);

		// TODO: This needs to deal with inherited members that have the same name.
		template membersToSerializeImpl(T, Members...)
		{
			static if (Members.length > 1)
			{
				static if (shouldSerializeMember!(Members[0]))
					alias membersToSerializeImpl = CTValSet!(Members[0], membersToSerializeImpl!(T, Members[1..$]));
				else
					alias membersToSerializeImpl = membersToSerializeImpl!(T, Members[1..$]);
			}
			else
			{
				static if (shouldSerializeMember!(Members[0]))
					alias membersToSerializeImpl = CTValSet!(Members[0]);
				else
					alias membersToSerializeImpl = CTValSet!();
			}
		}
		alias membersToSerialize = membersToSerializeImpl!(T, __traits(allMembers, T));
	}

	enum isMemberOptional(T, string member) = memberHasAttribute!(T, member, optional);
	
	static bool shouldSerializeValue(T, string member)(T val) @safe pure nothrow
	{
		static if (isMemberOptional!(T, member))
		{
			if (getDefaultMemberValue!(T, member) == getMemberValue!member(val))
				return false;
		}
		return true;
	}
	enum getFinalMemberName(T, string member) = memberHasAttribute!(T, member, serializeAs) ? getMemberAttribute!(T, member, serializeAs).Name : member;

	template BaseSerializationMembers()
	{
		enum BaseSerializationMembers = q{
			// This overload is designed to reduce the number of times the serialization
			// templates are instantiated. (and make the type checks within them much simpler)
			static void serialize(T)(ref BinaryOutputRange!OR output, T val) @trusted
				if (!isNativeSerializationSupported!T && !is(Dequal!T == T))
			{
				return serialize(output, cast(Dequal!T)val);
			}

			static void serialize(T)(ref BinaryOutputRange!OR output, T val) @trusted
				if (!isNativeSerializationSupported!T && is(Dequal!T == T))
			{
				static if (__traits(compiles, (cast(T)T.init).toString()) && __traits(compiles, T.parse("")))
				{
					// TODO: Support using an output range here as well.
					serialize(output, val.toString());
				}
				else
					static assert(0, typeof(this).stringof ~ " does not support serializing " ~ T.stringof ~ "s!");
			}
		};
	}

	template BaseDeserializationMembers()
	{
		enum BaseDeserializationMembers = q{

			static T deserializeValue(T, PT)(ref PT ctx) @trusted
				if (!isNativeSerializationSupported!T && !is(Dequal!T == T) && isDeserializationContext!PT)
			{
				return cast(T)deserializeValue!(Dequal!T)(ctx);
			}
			
			static T deserializeValue(T, PT)(ref PT ctx) @safe
				if (!isNativeSerializationSupported!T && is(Dequal!T == T) && isDeserializationContext!PT)
			{
				static if (__traits(compiles, (cast(T)T.init).toString()) && __traits(compiles, T.parse("")))
				{
					T v = T.parse(ctx.current.stringValue);
					ctx.consume();
					return v;
				}
				else
					static assert(0, typeof(this).stringof ~ " does not support deserializing " ~ T.stringof ~ "s!");
			}
		};
	}

public:
	abstract ubyte[] serialize(T)(T val);
	abstract T deserialize(T)(ubyte[] data);
}