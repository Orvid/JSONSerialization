module std.serialization;

enum optional;
enum serializable;
enum nonSerialized;
struct serializeAs { string Name; }

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
		isMemberField,
		memberHasAttribute
	;

	protected template isSerializable(T)
	{
		import std.traits : isBuiltinType;
		static if (isBuiltinType!T)
			enum isSerializable = true;
		else
			enum isSerializable = hasAttribute!(T, serializable) || is(Dequal!T == Object);
	}
	protected static void ensureSerializable(T)() @safe pure nothrow
	{
		static if (isClass!T)
			static assert(hasAttribute!(T, serializable) || is(Dequal!T == Object), "Classes not marked as serializable cannot be serialized!");
		else
			static assert(0, "Not yet implemented!");
	}

	protected static void ensurePublicConstructor(T)() @safe pure nothrow
	{
		static if (isClass!T)
			static assert(hasPublicDefaultConstructor!T, `The class '` ~ T.stringof ~ `' doesn't have a publicly visible constructor!`);
		else
			static assert(0, "Not yet implemented!");
	}

	protected template shouldSerializeMember(T, string member)
	{
		enum shouldSerializeMember = member != "this" && isMemberField!(T, member) && !memberHasAttribute!(T, member, nonSerialized);
	}
	
	protected static bool shouldSerializeValue(T, string member)(T val) @safe pure nothrow
	{
		static if (memberHasAttribute!(T, member, optional))
		{
			if (getDefaultMemberValue!(T, member) == getMemberValue!member(val))
				return false;
		}
		return true;
	}

	protected template getFinalMemberName(T, string member)
	{
		enum getFinalMemberName = memberHasAttribute!(T, member, serializeAs) ? getMemberAttribute!(T, member, serializeAs).Name : member;
	}

	template BaseMembers()
	{
		enum BaseMembers = q{
			// This overload is designed to reduce the number of times the serialization
			// templates are instantiated. (and make the type checks within them much simpler)
			static void serialize(Range, T)(ref Range output, T val) @trusted
				if (!isNativeSerializationSupported!T && !is(Dequal!T == T) && isOutputRange!(Range, string))
			{
				return serialize(output, cast(Dequal!T)val);
			}
			static void serialize(Range, T)(ref Range output, T val) @trusted
				if (!isNativeSerializationSupported!T && is(Dequal!T == T) && isOutputRange!(Range, string))
			{
				static assert(0, typeof(this).stringof ~ " does not support serializing " ~ T.stringof ~ "s!");
			}
		};
	}


	abstract ubyte[] serialize(T)(T val);
	abstract T deserialize(T)(ubyte[] data);
}