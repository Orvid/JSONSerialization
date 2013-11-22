module std.serialization.core;

import std.range : isInputRange, isOutputRange;

enum optional;
enum serializable;
enum nonSerialized;
struct serializeAs { string Name; }

struct BinaryInputRange(IR)
	if (isInputRange!(IR, ubyte[]))
{

}

struct BinaryOutputRange(OR)
	if (isOutputRange!(OR, ubyte[]))
{
	import std.traits : isIntegral, isSomeChar;

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
		if (isIntegral!C || isSomeChar!C)
	{
		mInnerRange.put(cast(ubyte[])arr);
	}
	
	void put(C)(C c) @trusted
		if (isIntegral!C || isSomeChar!C)
	{
		static if (C.sizeof == 1)
		{
			mInnerRange.put(cast(ubyte)c);
		}
		else
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
	static assert(!isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), float[]));
	static assert(!isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), double[]));
	static assert(!isOutputRange!(BinaryOutputRange!(Appender!(ubyte[])), real[]));
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
		// TODO: This is currently required due to
		// an issue with evaluation order and templates.
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
			ret.put(`private enum expectedFieldsEnum = BitArray!`);
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
			ret.put(`private static immutable expectedFields = expectedFieldsEnum;`);
			
			return ret.data;
		}
		
		@property void markSerialized(string member)() @safe pure nothrow
		{
			import std.typecons : staticIndexOf;
			
			fieldMarkers[staticIndexOf!(member, members)] = true;
		}
		
		void ensureFullySerialized() @safe pure
		{
			// TODO: A bug in DMD means that expectedFields isn't accessible in
			//       CTFE. Once that's fixed, change this.
			if (__ctfe)
			{
				fieldMarkers &= expectedFieldsEnum;
				if (fieldMarkers != expectedFieldsEnum)
					throw new Exception("A required field was not deserialized!");
			}
			else
			{
				fieldMarkers &= expectedFields;
				if (fieldMarkers != expectedFields)
					throw new Exception("A required field was not deserialized!");
			}
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
				import std.conv : to;
				import std.traits : isBuiltinType;
				import std.traitsExt : isEnum;
				
				// TODO: Figure out a way that this can be done without needing to
				//       allocate a string for the value. Unfortunately this currently
				//       is prevented by the need to process the actual string.
				static if (__traits(compiles, (cast(T)T.init).toString()) && __traits(compiles, T.parse("")))
				{
					serialize(output, val.toString());
				}
				else static if ((isBuiltinType!T || isEnum!T) && __traits(compiles, to!string(cast(T)T.init)))
				{
					serialize(output, to!string(val));
				}
				else
					static assert(0, typeof(this).stringof ~ " does not support serializing a " ~ T.stringof ~ ", and the type does not implement parse and toString!");
			}
		};
	}
	
	template BaseDeserializationMembers()
	{
		enum BaseDeserializationMembers = q{
			// This overload is designed to reduce the number of times the deserialization
			// templates are instantiated. (and make the type checks within them much simpler)
			static T deserializeValue(T, PT)(ref PT ctx) @trusted
				if (!isNativeSerializationSupported!T && !is(Dequal!T == T) && isDeserializationContext!PT)
			{
				return cast(T)deserializeValue!(Dequal!T)(ctx);
			}
			
			static T deserializeValue(T, PT)(ref PT ctx) @safe
				if (!isNativeSerializationSupported!T && is(Dequal!T == T) && isDeserializationContext!PT)
			{
				import std.conv : to;
				import std.traits : isBuiltinType;
				import std.traitsExt : isEnum;
				
				static if (__traits(compiles, (cast(T)T.init).toString()) && __traits(compiles, T.parse("")))
				{
					T v = T.parse(ctx.current.stringValue);
					ctx.consume();
					return v;
				}
				else static if (__traits(compiles, to!T("")))
				{
					T v = to!T(ctx.current.stringValue);
					ctx.consume();
					return v;
				}
				else
					static assert(0, typeof(this).stringof ~ " does not support deserializing a " ~ T.stringof ~ ", and the type does not implement parse and toString!");
			}
		};
	}
	
public:
	abstract ubyte[] serialize(T)(T val);
	abstract T deserialize(T)(ubyte[] data);
}

version (unittest)
{
	import std.algorithm : equal;
	import std.conv : to;
	import std.testing : assertStaticAndRuntime;

	// This is the framework for testing serialization format implementations.
	enum Test
	{
		PrivateConstructor,
		NonSerializable,
		OptionalField,
		NonSerializedField,
		SerializeAsField,
		ByteField,
		UByteField,
		ShortField,
		UShortField,
		IntField,
		UIntField,
		LongField,
		ULongField,
		CentField,
		UCentField,
		FloatField,
		DoubleField,
		RealField,
		CharField,
		WCharField,
		DCharField,
		StringField,
		WStringField,
		WCharArrayField,
		ConstWCharArrayField,
		DStringField,
		FalseBoolField,
		TrueBoolField,
		NullObjectField,
		ClassField,
		ClassArrayField,
		IntArrayField,
		StructParent,
		StructField,
		ParsableClassField,
		EnumField,
	}
	static void runSerializationTests(T, alias serialize, alias deserialize, alias tests)()
	{
		static @property void staticEach(alias vals, alias action, params...)()
		{
			import std.traits : isAssociativeArray;
			
			static if (isAssociativeArray!(typeof(vals)))
			{
				static void staticEachImpl(alias keys, alias vals, alias action, params...)()
				{
					static if (vals.length == 0) { } // Do nothing
					else static if (vals.length == 1)
					{
						action!(keys[0], vals[0], params)();
					}
					else
					{
						action!(keys[0], vals[0], params)();
						staticEachImpl!(keys[1..$], vals[1..$], action, params);
					}
				}
				staticEachImpl!(vals.keys(), vals.values(), action, params)();
			}
			else
			{
				static if (vals.length == 0) { } // Do nothing
				else static if (vals.length == 1)
				{
					action!(vals[0], params)();
				}
				else
				{
					action!(vals[0], params)();
					staticEach!(vals[1..$], action, params);
				}
			}
		}
		// TODO: Ensure that all test types are passed in.
		//foreach (k, v; tests)
		static void testImpl(Test k, alias v)()
		{
			static void innerImpl(string str)()
			{
				static if (k == Test.PrivateConstructor)
				{
					@serializable static class PrivateConstructor { private this() { } @optional int A = 3; int B = 5; }
					static assert(!__traits(compiles, { assertStaticAndRuntime!(serialize(new PrivateConstructor()) == str); }), "A private constructor was allowed for a serializable class while attempting serialization!");
					static assert(!__traits(compiles, { assertStaticAndRuntime!(deserialize!PrivateConstructor(str).B == 5); }), "A private constructor was allowed for a serializable class while attempting deserialization!");
				}
				else static if (k == Test.NonSerializable)
				{
					static class NonSerializable { @optional int A = 3; int B = 5; }
					assertStaticAndRuntime!(!__traits(compiles, { assert(serialize(new NonSerializable()) == `{"B":5}`); }), "A class not marked with @serializable was allowed while attempting serialization!");
					assertStaticAndRuntime!(!__traits(compiles, { assert(deserialize!NonSerializable(`{"B":5}`).B == 5); }), "A class not marked with @serializable was allowed while attempting deserialization!");
				}
				else static if (k == Test.OptionalField)
				{
					@serializable static class OptionalField { @optional int A = 3; int B = 5; }
					assertStaticAndRuntime!(serialize(new OptionalField()) == `{"B":5}`, "An optional field set to its default value was not excluded!");
					assertStaticAndRuntime!(() {
						auto cfa = deserialize!OptionalField(`{"B":5}`);
						assert(cfa.A == 3);
						assert(cfa.B == 5);
						return true;
					}(), "Failed to correctly deserialize a class with an optional field!");
				}
				else static if (k == Test.NonSerializedField)
				{
					@serializable static class NonSerializedField { int A = 3; @nonSerialized int B = 2; }
					assertStaticAndRuntime!(serialize(new NonSerializedField()) == `{"A":3}`, "A field marked with @nonSerialized was included!");
					assertStaticAndRuntime!(deserialize!NonSerializedField(`{"A":3}`).A == 3, "Failed to correctly deserialize a class when a field marked with @nonSerialized was present!");
				}
				else static if (k == Test.SerializeAsField)
				{
					@serializable static class SerializeAsField { int A = 3; @serializeAs(`D`) int B = 5; @nonSerialized int D = 7; }
					assertStaticAndRuntime!(serialize(new SerializeAsField()) == `{"A":3,"D":5}`, "A field marked with @serializeAs(`D`) failed to serialize as D!");
					assertStaticAndRuntime!(() {
						auto cfa = deserialize!SerializeAsField(`{"A":3,"D":5}`);
						assert(cfa.A == 3);
						assert(cfa.B == 5);
						assert(cfa.D == 7);
						return true;
					}(), "Failed to correctly deserialize a class when a field marked with @serializeAs was present!");
				}
				else static if (k == Test.ByteField)
				{
					@serializable static class ByteField { byte A = -3; }
					assertStaticAndRuntime!(serialize(new ByteField()) == `{"A":-3}`, "Failed to correctly serialize a byte field!");
					assertStaticAndRuntime!(deserialize!ByteField(`{"A":-3}`).A == -3, "Failed to correctly deserialize a byte field!");
					assertStaticAndRuntime!(deserialize!ByteField(`{"A":"-3"}`).A == -3, "Failed to correctly deserialize a byte field set to the quoted value '-3'!");
				}
				else static if (k == Test.UByteField)
				{
					@serializable static class UByteField { ubyte A = 159; }
					assertStaticAndRuntime!(serialize(new UByteField()) == `{"A":159}`, "Failed to correctly serialize a ubyte field!");
					assertStaticAndRuntime!(deserialize!UByteField(`{"A":159}`).A == 159, "Failed to correctly deserialize a ubyte field!");
					assertStaticAndRuntime!(deserialize!UByteField(`{"A":"159"}`).A == 159, "Failed to correctly deserialize a ubyte field set to the quoted value '159'!");
				}
				else static if (k == Test.ShortField)
				{
					@serializable static class ShortField { short A = -26125; }
					assertStaticAndRuntime!(serialize(new ShortField()) == `{"A":-26125}`, "Failed to correctly serialize a short field!");
					assertStaticAndRuntime!(deserialize!ShortField(`{"A":-26125}`).A == -26125, "Failed to correctly deserialize a short field!");
					assertStaticAndRuntime!(deserialize!ShortField(`{"A":"-26125"}`).A == -26125, "Failed to correctly deserialize a short field set to the quoted value '-26125'!");
				}
				else static if (k == Test.UShortField)
				{
					@serializable static class UShortField { ushort A = 65313; }
					assertStaticAndRuntime!(serialize(new UShortField()) == `{"A":65313}`, "Failed to correctly serialize a ushort field!");
					assertStaticAndRuntime!(deserialize!UShortField(`{"A":65313}`).A == 65313, "Failed to correctly deserialize a ushort field!");
					assertStaticAndRuntime!(deserialize!UShortField(`{"A":"65313"}`).A == 65313, "Failed to correctly deserialize a ushort field set to the quoted value '65313'!");
				}
				else static if (k == Test.IntField)
				{
					@serializable static class IntField { int A = -2032534342; }
					assertStaticAndRuntime!(serialize(new IntField()) == `{"A":-2032534342}`, "Failed to correctly serialize an int field!");
					assertStaticAndRuntime!(deserialize!IntField(`{"A":-2032534342}`).A == -2032534342, "Failed to correctly deserialize an int field!");
					assertStaticAndRuntime!(deserialize!IntField(`{"A":"-2032534342"}`).A == -2032534342, "Failed to correctly deserialize an int field set to the quoted value '-2032534342'!");
				}
				else static if (k == Test.UIntField)
				{
					@serializable static class UIntField { uint A = 2520041234; }
					assertStaticAndRuntime!(serialize(new UIntField()) == `{"A":2520041234}`, "Failed to correctly serialize a uint field!");
					assertStaticAndRuntime!(deserialize!UIntField(`{"A":2520041234}`).A == 2520041234, "Failed to correctly deserialize a uint field!");
					assertStaticAndRuntime!(deserialize!UIntField(`{"A":"2520041234"}`).A == 2520041234, "Failed to correctly deserialize a uint field set to the quoted value '2520041234'!");
				}
				else static if (k == Test.LongField)
				{
					@serializable static class LongField { long A = -2305393212345134623; }
					assertStaticAndRuntime!(serialize(new LongField()) == `{"A":-2305393212345134623}`, "Failed to correctly serialize a long field!");
					assertStaticAndRuntime!(deserialize!LongField(`{"A":-2305393212345134623}`).A == -2305393212345134623, "Failed to correctly deserialize a long field!");
					assertStaticAndRuntime!(deserialize!LongField(`{"A":"-2305393212345134623"}`).A == -2305393212345134623, "Failed to correctly deserialize a long field set to the quoted value '-2305393212345134623'!");
				}
				else static if (k == Test.ULongField)
				{
					@serializable static class ULongField { ulong A = 4021352154138321354; }
					assertStaticAndRuntime!(serialize(new ULongField()) == `{"A":4021352154138321354}`, "Failed to correctly serialize a ulong field!");
					assertStaticAndRuntime!(deserialize!ULongField(`{"A":4021352154138321354}`).A == 4021352154138321354, "Failed to correctly deserialize a ulong field!");
					assertStaticAndRuntime!(deserialize!ULongField(`{"A":"4021352154138321354"}`).A == 4021352154138321354, "Failed to correctly deserialize a ulong field set to the quoted value '4021352154138321354'!");
				}
				else static if (k == Test.CentField)
				{
					//@serializable static class CentField { cent A = -23932104152349231532145324134; }
					//assertStaticAndRuntime!(serialize(new CentField()) == `{"A":-23932104152349231532145324134}`, "Failed to correctly serialize a cent field!");
					//assertStaticAndRuntime!(deserialize!CentField(`{"A":-23932104152349231532145324134}`).A == -23932104152349231532145324134, "Failed to correctly deserialize a cent field!");
					//assertStaticAndRuntime!(deserialize!CentField(`{"A":"-23932104152349231532145324134"}`).A == -23932104152349231532145324134, "Failed to correctly deserialize a cent field set to the quoted value '-23932104152349231532145324134'!");
				}
				else static if (k == Test.UCentField)
				{
					//@serializable static class UCentField { ucent A = 40532432168321451235829354323; }
					//assertStaticAndRuntime!(serialize(new UCentField()) == `{"A":40532432168321451235829354323}`, "Failed to correctly serialize a ucent field!");
					//assertStaticAndRuntime!(deserialize!UCentField(`{"A":40532432168321451235829354323}`).A == 40532432168321451235829354323, "Failed to correctly deserialize a ucent field!");
					//assertStaticAndRuntime!(deserialize!UCentField(`{"A":"40532432168321451235829354323"}`).A == 40532432168321451235829354323, "Failed to correctly deserialize a ucent field set to the quoted value '40532432168321451235829354323'!");
				}
				else static if (k == Test.FloatField)
				{
					// TODO: Test NaN and infinite support.
					// TODO: Why on earth does this have no decimals???
					@serializable static class FloatField { float A = -433200; }
					// TODO: Make this static once float -> string conversion is possible in CTFE
					assert(serialize(new FloatField()) == `{"A":-433200}`, "Failed to correctly serialize a float field!");
					assertStaticAndRuntime!(deserialize!FloatField(`{"A":-433200}`).A == -433200, "Failed to correctly deserialize a float field!");
					assertStaticAndRuntime!(deserialize!FloatField(`{"A":"-433200"}`).A == -433200, "Failed to correctly deserialize a float field set to the quoted value '-433200'!");
				}
				else static if (k == Test.DoubleField)
				{
					@serializable static class DoubleField { double A = 3.25432e+53; }
					// TODO: Make this static once double -> string conversion is possible in CTFE
					assert(serialize(new DoubleField()) == `{"A":3.25432e+53}`, "Failed to correctly serialize a double field!");
					assertStaticAndRuntime!(deserialize!DoubleField(`{"A":3.25432e+53}`).A == 3.25432e+53, "Failed to correctly deserialize a double field!");
					assertStaticAndRuntime!(deserialize!DoubleField(`{"A":"3.25432e+53"}`).A == 3.25432e+53, "Failed to correctly deserialize a double field set to the quoted value '3.25432e+53'!");
				}
				else static if (k == Test.RealField)
				{
					@serializable static class RealField { real A = -2.13954e+104; }
					// TODO: Make this static once real -> string conversion is possible in CTFE
					assert(serialize(new RealField()) == `{"A":-2.13954e+104}`, "Failed to correctly serialize a real field!");
					assertStaticAndRuntime!(deserialize!RealField(`{"A":-2.13954e+104}`).A == -2.13954e+104, "Failed to correctly deserialize a real field!");
					assertStaticAndRuntime!(deserialize!RealField(`{"A":"-2.13954e+104"}`).A == -2.13954e+104, "Failed to correctly deserialize a real field set to the quoted value '-2.13954e+104'!");
				}
				else static if (k == Test.CharField)
				{
					@serializable static class CharField { char A = '\x05'; }
					assertStaticAndRuntime!(serialize(new CharField()) == `{"A":"\u0005"}`, "Failed to correctly serialize a char field!");
					assertStaticAndRuntime!(deserialize!CharField(`{"A":"\u0005"}`).A == '\x05', "Failed to correctly deserialize a char field!");
				}
				else static if (k == Test.WCharField)
				{
					@serializable static class WCharField { wchar A = '\u04DA'; }
					assertStaticAndRuntime!(serialize(new WCharField()) == `{"A":"\u04DA"}`, "Failed to correctly serialize a wchar field!");
					assertStaticAndRuntime!(deserialize!WCharField(`{"A":"\u04DA"}`).A == '\u04DA', "Failed to correctly deserialize a wchar field!");
				}
				else static if (k == Test.DCharField)
				{
					@serializable static class DCharField { dchar A = '\U0010FFFF'; }
					assertStaticAndRuntime!(serialize(new DCharField()) == `{"A":"\x0010FFFF"}`, "Failed to correctly serialize a dchar field!");
					assertStaticAndRuntime!(deserialize!DCharField(`{"A":"\x0010FFFF"}`).A == '\U0010FFFF', "Failed to correctly deserialize a dchar field!");
				}
				else static if (k == Test.StringField)
				{
					@serializable static class StringField { string A = "Hello!\b\"\u08A8\U0010FFFF"; }
					assertStaticAndRuntime!(serialize(new StringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a string field!");
					assertStaticAndRuntime!(deserialize!StringField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A == "Hello!\b\"\u08A8\U0010FFFF", "Failed to correctly deserialize a string field!");
				}
				else static if (k == Test.WStringField)
				{
					@serializable static class WStringField { wstring A = "Hello!\b\"\u08A8\U0010FFFF"w; }
					assertStaticAndRuntime!(serialize(new WStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wstring field!");
					assertStaticAndRuntime!(deserialize!WStringField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A == "Hello!\b\"\u08A8\U0010FFFF"w, "Failed to correctly deserialize a wstring field!");
				}
				else static if (k == Test.WCharArrayField)
				{
					() @trusted {
						@serializable static class WCharArrayField { wchar[] A = cast(wchar[])"Hello!\b\"\u08A8\U0010FFFF"w; }
						assertStaticAndRuntime!(serialize(new WCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wchar[] field!");
						assertStaticAndRuntime!(deserialize!WCharArrayField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A.equal(cast(wchar[])"Hello!\b\"\u08A8\U0010FFFF"w), "Failed to correctly deserialize a wchar[] field!");
					}();
				}
				else static if (k == Test.ConstWCharArrayField)
				{
					@serializable static class ConstWCharArrayField { const(wchar)[] A = "Hello!\b\"\u08A8\U0010FFFF"w; }
					assertStaticAndRuntime!(serialize(new ConstWCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a const(wchar)[] field!");
					assertStaticAndRuntime!(deserialize!ConstWCharArrayField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A.equal("Hello!\b\"\u08A8\U0010FFFF"w), "Failed to correctly deserialize a const(wchar)[] field!");
				}
				else static if (k == Test.DStringField)
				{
					@serializable static class DStringField { dstring A = "Hello!\b\"\u08A8\U0010FFFF"d; }
					assertStaticAndRuntime!(serialize(new DStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a dstring field!");
					assertStaticAndRuntime!(deserialize!DStringField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A == "Hello!\b\"\u08A8\U0010FFFF"d, "Failed to correctly deserialize a dstring field!");
				}
				else static if (k == Test.FalseBoolField)
				{
					@serializable static class FalseBoolField { bool A; auto Init() { A = false; return this; } }
					assertStaticAndRuntime!(serialize((new FalseBoolField()).Init()) == `{"A":false}`, "Failed to correctly serialize a bool field set to false!");
					assertStaticAndRuntime!(deserialize!FalseBoolField(`{"A":false}`).A == false, "Failed to correctly deserialize a bool field set to false!");
					assertStaticAndRuntime!(deserialize!FalseBoolField(`{"A":"false"}`).A == false, "Failed to correctly deserialize a bool field set to the quoted value 'false'!");
				}
				else static if (k == Test.TrueBoolField)
				{
					@serializable static class TrueBoolField { bool A; auto Init() { A = true; return this; } }
					assertStaticAndRuntime!(serialize((new TrueBoolField()).Init()) == `{"A":true}`, "Failed to correctly serialize a bool field set to true!");
					assertStaticAndRuntime!(deserialize!TrueBoolField(`{"A":true}`).A == true, "Failed to correctly deserialize a bool field set to true!");
					assertStaticAndRuntime!(deserialize!TrueBoolField(`{"A":"true"}`).A == true, "Failed to correctly deserialize a bool field set to the quoted value 'true'!");
					assertStaticAndRuntime!(deserialize!TrueBoolField(`{"A":"True"}`).A == true, "Failed to correctly deserialize a bool field set to the quoted value 'True'!");
					assertStaticAndRuntime!(deserialize!TrueBoolField(`{"A":"tRUe"}`).A == true, "Failed to correctly deserialize a bool field set to the quoted value 'tRUe'!");
				}
				else static if (k == Test.NullObjectField)
				{
					@serializable static class NullObjectField { Object A = null; }
					assertStaticAndRuntime!(serialize(new NullObjectField()) == `{"A":null}`, "Failed to correctly serialize an Object field set to null!");
					assertStaticAndRuntime!(deserialize!NullObjectField(`{"A":null}`).A is null, "Failed to correctly deserialize an Object field set to null!"); 
					assertStaticAndRuntime!(deserialize!NullObjectField(`{"A":"null"}`).A is null, "Failed to correctly deserialize an Object field set to the quoted value 'null'!"); 
				}
				else static if (k == Test.ClassField)
				{
					@serializable static class SerializeAsField2 { int A = 3; @serializeAs(`D`) int B = 5; @nonSerialized int D = 7; }
					@serializable static class ClassField { SerializeAsField2 A = new SerializeAsField2(); }
					assertStaticAndRuntime!(serialize(new ClassField()) == `{"A":{"A":3,"D":5}}`, "Failed to correctly serialize a class field!");
					assertStaticAndRuntime!(() {
						auto cfa = deserialize!ClassField(`{"A":{"A":3,"D":5}}`);
						assert(cfa.A);
						assert(cfa.A.A == 3);
						assert(cfa.A.B == 5);
						assert(cfa.A.D == 7);
						return true;
					}(), "Failed to correctly deserialize a class field!");
				}
				else static if (k == Test.ClassArrayField)
				{
					@serializable static class SerializeAsField3 { int A = 3; @serializeAs(`D`) int B = 5; @nonSerialized int D = 7; }
					@serializable static class ClassArrayField { SerializeAsField3[] A = [new SerializeAsField3(), new SerializeAsField3()]; }
					assertStaticAndRuntime!(serialize(new ClassArrayField()) == `{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`, "Failed to correctly serialize a class array field!");
					assertStaticAndRuntime!(() {
						auto cfa = deserialize!ClassArrayField(`{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`);
						assert(cfa.A);
						assert(cfa.A.length == 2);
						assert(cfa.A[0].A == 3);
						assert(cfa.A[0].B == 5);
						assert(cfa.A[1].A == 3);
						assert(cfa.A[1].B == 5);
						return true;
					}(), "Failed to correctly deserialize a class array field!");
				}
				else static if (k == Test.IntArrayField)
				{
					@serializable static class IntArrayField { int[] A = [-3, 6, 190]; }
					assertStaticAndRuntime!(serialize(new IntArrayField()) == `{"A":[-3,6,190]}`, "Failed to correctly serialize an int[] field!");
					assertStaticAndRuntime!(deserialize!IntArrayField(`{"A":[-3,6,190]}`).A.equal([-3, 6, 190]), "Failed to correctly deserialize an int[] field!");
				}
				else static if (k == Test.StructParent)
				{
					@serializable static struct StructParent { int A = 3; }
					assertStaticAndRuntime!(serialize(StructParent()) == `{"A":3}`, "Failed to correctly serialize a structure!");
					assertStaticAndRuntime!(deserialize!StructParent(`{"A":3}`).A == 3, "Failed to correctly deserialize a structure!");
				}
				else static if (k == Test.StructField)
				{
					@serializable static struct StructParent2 { int A = 3; }
					@serializable static struct StructField { StructParent2 A; }
					assertStaticAndRuntime!(serialize(StructField()) == `{"A":{"A":3}}`, "Failed to correctly serialize a struct field!");
					assertStaticAndRuntime!(deserialize!StructField(`{"A":{"A":4}}`).A.A == 4, "Failed to correctly deserialize a struct field!");
				}
				else static if (k == Test.ParsableClassField)
				{
					static class ParsableClass 
					{
						import std.conv : to;
						
						int A = 3;
						
						override string toString() @safe pure { return to!string(A); }
						static typeof(this) parse(string str) @safe pure
						{
							auto p = new ParsableClass();
							p.A = to!int(str);
							return p;
						}
					}
					@serializable static class ParsableClassField { ParsableClass A = new ParsableClass(); }
					assertStaticAndRuntime!(serialize(new ParsableClassField()) == str, "Failed to correctly serialize a non-serializable parsable class!");
					assertStaticAndRuntime!(deserialize!ParsableClassField(str).A.A == 3, "Failed to correctly deserialize a non-serializable parsable class!");
				}
				else static if (k == Test.EnumField)
				{
					enum EnumTest { valA, valB, valC }
					@serializable static class EnumField { EnumTest A = EnumTest.valB; }
					assertStaticAndRuntime!(serialize(new EnumField()) == str, "Failed to correctly serialize an enum!");
					assertStaticAndRuntime!(deserialize!EnumField(str).A == EnumTest.valB, "Failed to correctly deserialize an enum!");
				}
				else
					static assert(0, "This test isn't implemented, woops!");
			}
			staticEach!(v, innerImpl);
		}
		staticEach!(tests, testImpl);
	}
}