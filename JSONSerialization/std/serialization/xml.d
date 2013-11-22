module std.serialization.xml;

import std.range : isOutputRange;
import std.serialization : BinaryOutputRange, SerializationFormat;
import std.traits : isArray;

final class XMLSerializationFormat : SerializationFormat
{
	template isNativeSerializationSupported(T)
	{
		import std.traits : ForeachType;

		static if (is(Dequal!T == T))
		{
			static if (is(T == char[]))
			{
				enum isNativeSerializationSupported = true;
			}
			else static if (isArray!T)
			{
				enum isNativeSerializationSupported = isNativeSerializationSupported!(ForeachType!T);
			}
			else static if (isSerializable!T)
			{
				enum isNativeSerializationSupported = isClass!T || isStruct!T;
			}
			else
				enum isNativeSerializationSupported = false;
		}
		else
		{
			enum isNativeSerializationSupported = false;
		}
	}


	static struct InnerFunStuff(OR)
		if (isOutputRange!(OR, ubyte[]))
	{
		// TODO: Why must D be a pain at times....
		mixin(BaseSerializationMembers!());

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @safe
			if (isNativeSerializationSupported!T && is(T == char[]))
		{
			output.put(val);
		}

		/// ditto
		static void serialize(T)(ref BinaryOutputRange!OR output, T val) @safe
			if (isNativeSerializationSupported!T && (isClass!T || isStruct!T))
		{
			static if (isClass!T)
			{
				if (!val)
				{
					output.put("");
					return;
				}
				else static if (is(T == Object))
				{
					output.put("<Object/>");
					return;
				}
			}
			ensurePublicConstructor!T();
			output.put("<" ~ T.stringof ~ ">");
			size_t i = 0;
			foreach (member; membersToSerialize!T)
			{
				import std.traitsExt : getMemberValue;
				
				if (!shouldSerializeValue!(T, member)(val))
					continue;
				output.put("<" ~ getFinalMemberName!(T, member) ~ ">");
				serialize(output, getMemberValue!member(val));
				output.put("</" ~ getFinalMemberName!(T, member) ~ ">");
			}
			output.put("</" ~ T.stringof ~ ">");
		}
	}

	
	static T fromXML(T)(string val) @safe
	{
		return T.init;
		//auto parser = XMLLexer!string(val);
		
		//return deserializeValue!T(parser);
	}
}


void toXML(T, OR)(T val, ref OR buf) @safe
	if (isOutputRange!(OR, ubyte[]))
{
	auto bor = BinaryOutputRange!OR(buf);
	XMLSerializationFormat.InnerFunStuff!(OR).serialize(bor, val);
	buf = bor.innerRange;
}

string toXML(T)(T val) @trusted 
{
	import std.performance.array : Appender;
	
	auto ret = BinaryOutputRange!(Appender!(ubyte[]))();
	XMLSerializationFormat.InnerFunStuff!(Appender!(ubyte[])).serialize(ret, val);
	return cast(string)ret.data;
}
T fromXML(T)(string val) @safe 
{
	return XMLSerializationFormat.fromXML!T(val); 
}


unittest
{
	import std.algorithm : equal;
	import std.conv : to;
	import std.serialization : nonSerialized, optional, serializeAs, serializable;
	import std.testing : assertStaticAndRuntime;

//	@serializable static class PrivateConstructor { private this() { } @optional int A = 3; int B = 5; }
//	assertStaticAndRuntime!(!__traits(compiles, { assert(toXML(new PrivateConstructor()) == `<PrivateConstructor><B>5</B></PrivateConstructor>`); }), "A private constructor was allowed for a serializable class while attempting serialization!");
//	//assertStaticAndRuntime!(!__traits(compiles, { assert(fromXML!PrivateConstructor(`{"B":5}`).B == 5); }), "A private constructor was allowed for a serializable class while attempting deserialization!");
//	
//	static class NonSerializable { @optional int A = 3; int B = 5; }
//	assertStaticAndRuntime!(!__traits(compiles, { assert(toXML(new NonSerializable()) == `<NonSerializable><B>5</B></NonSerializable>`); }), "A class not marked with @serializable was allowed while attempting serialization!");
//	//assertStaticAndRuntime!(!__traits(compiles, { assert(fromXML!NonSerializable(`{"B":5}`).B == 5); }), "A class not marked with @serializable was allowed while attempting deserialization!");
//	
//	@serializable static class OptionalField { @optional int A = 3; int B = 5; }
//	assertStaticAndRuntime!(toXML(new OptionalField()) == `<OptionalField B="5"/>`, "An optional field set to its default value was not excluded!");
//	assertStaticAndRuntime!(() {
//		auto cfa = fromXML!OptionalField(`<OptionalField B="5"/>`);
//		assert(cfa.A == 3);
//		assert(cfa.B == 5);
//		return true;
//	}(), "Failed to correctly deserialize a class with an optional field!");
//	
//	@serializable static class NonSerializedField { int A = 3; @nonSerialized int B = 2; }
//	assertStaticAndRuntime!(toXML(new NonSerializedField()) == `<NonSerializedField A="3"/>`, "A field marked with @nonSerialized was included!");
//	assertStaticAndRuntime!(fromXML!NonSerializedField(`<NonSerializedField A="3"/>`).A == 3, "Failed to correctly deserialize a class when a field marked with @nonSerialized was present!");
//	
//	@serializable static class SerializeAsField { int A = 3; @serializeAs(`D`) int B = 5; @nonSerialized int D = 7; }
//	assertStaticAndRuntime!(toXML(new SerializeAsField()) == `<SerializeAsField A="3" D="5"/>`, "A field marked with @serializeAs(`D`) failed to serialize as D!");
//	assertStaticAndRuntime!(() {
//		auto cfa = fromXML!SerializeAsField(`<SerializeAsField A="3" D="5"/>`);
//		assert(cfa.A == 3);
//		assert(cfa.B == 5);
//		assert(cfa.D == 7);
//		return true;
//	}(), "Failed to correctly deserialize a class when a field marked with @serializeAs was present!");
//	
//	@serializable static class ByteField { byte A = -3; }
//	assertStaticAndRuntime!(toXML(new ByteField()) == `{"A":-3}`, "Failed to correctly serialize a byte field!");
//	assertStaticAndRuntime!(fromXML!ByteField(`{"A":-3}`).A == -3, "Failed to correctly deserialize a byte field!");
//	assertStaticAndRuntime!(fromXML!ByteField(`{"A":"-3"}`).A == -3, "Failed to correctly deserialize a byte field set to the quoted value '-3'!");
//	
//	@serializable static class UByteField { ubyte A = 159; }
//	assertStaticAndRuntime!(toXML(new UByteField()) == `{"A":159}`, "Failed to correctly serialize a ubyte field!");
//	assertStaticAndRuntime!(fromXML!UByteField(`{"A":159}`).A == 159, "Failed to correctly deserialize a ubyte field!");
//	assertStaticAndRuntime!(fromXML!UByteField(`{"A":"159"}`).A == 159, "Failed to correctly deserialize a ubyte field set to the quoted value '159'!");
//	
//	@serializable static class ShortField { short A = -26125; }
//	assertStaticAndRuntime!(toXML(new ShortField()) == `{"A":-26125}`, "Failed to correctly serialize a short field!");
//	assertStaticAndRuntime!(fromXML!ShortField(`{"A":-26125}`).A == -26125, "Failed to correctly deserialize a short field!");
//	assertStaticAndRuntime!(fromXML!ShortField(`{"A":"-26125"}`).A == -26125, "Failed to correctly deserialize a short field set to the quoted value '-26125'!");
//	
//	@serializable static class UShortField { ushort A = 65313; }
//	assertStaticAndRuntime!(toXML(new UShortField()) == `{"A":65313}`, "Failed to correctly serialize a ushort field!");
//	assertStaticAndRuntime!(fromXML!UShortField(`{"A":65313}`).A == 65313, "Failed to correctly deserialize a ushort field!");
//	assertStaticAndRuntime!(fromXML!UShortField(`{"A":"65313"}`).A == 65313, "Failed to correctly deserialize a ushort field set to the quoted value '65313'!");
//	
//	@serializable static class IntField { int A = -2032534342; }
//	assertStaticAndRuntime!(toXML(new IntField()) == `{"A":-2032534342}`, "Failed to correctly serialize an int field!");
//	assertStaticAndRuntime!(fromXML!IntField(`{"A":-2032534342}`).A == -2032534342, "Failed to correctly deserialize an int field!");
//	assertStaticAndRuntime!(fromXML!IntField(`{"A":"-2032534342"}`).A == -2032534342, "Failed to correctly deserialize an int field set to the quoted value '-2032534342'!");
//	
//	@serializable static class UIntField { uint A = 2520041234; }
//	assertStaticAndRuntime!(toXML(new UIntField()) == `{"A":2520041234}`, "Failed to correctly serialize a uint field!");
//	assertStaticAndRuntime!(fromXML!UIntField(`{"A":2520041234}`).A == 2520041234, "Failed to correctly deserialize a uint field!");
//	assertStaticAndRuntime!(fromXML!UIntField(`{"A":"2520041234"}`).A == 2520041234, "Failed to correctly deserialize a uint field set to the quoted value '2520041234'!");
//	
//	@serializable static class LongField { long A = -2305393212345134623; }
//	assertStaticAndRuntime!(toXML(new LongField()) == `{"A":-2305393212345134623}`, "Failed to correctly serialize a long field!");
//	assertStaticAndRuntime!(fromXML!LongField(`{"A":-2305393212345134623}`).A == -2305393212345134623, "Failed to correctly deserialize a long field!");
//	assertStaticAndRuntime!(fromXML!LongField(`{"A":"-2305393212345134623"}`).A == -2305393212345134623, "Failed to correctly deserialize a long field set to the quoted value '-2305393212345134623'!");
//	
//	@serializable static class ULongField { ulong A = 4021352154138321354; }
//	assertStaticAndRuntime!(toXML(new ULongField()) == `{"A":4021352154138321354}`, "Failed to correctly serialize a ulong field!");
//	assertStaticAndRuntime!(fromXML!ULongField(`{"A":4021352154138321354}`).A == 4021352154138321354, "Failed to correctly deserialize a ulong field!");
//	assertStaticAndRuntime!(fromXML!ULongField(`{"A":"4021352154138321354"}`).A == 4021352154138321354, "Failed to correctly deserialize a ulong field set to the quoted value '4021352154138321354'!");
//	
//	//@serializable static class CentField { cent A = -23932104152349231532145324134; }
//	//assertStaticAndRuntime!(toXML(new CentField()) == `{"A":-23932104152349231532145324134}`, "Failed to correctly serialize a cent field!");
//	//assertStaticAndRuntime!(fromXML!CentField(`{"A":-23932104152349231532145324134}`).A == -23932104152349231532145324134, "Failed to correctly deserialize a cent field!");
//	//assertStaticAndRuntime!(fromXML!CentField(`{"A":"-23932104152349231532145324134"}`).A == -23932104152349231532145324134, "Failed to correctly deserialize a cent field set to the quoted value '-23932104152349231532145324134'!");
//	
//	//@serializable static class UCentField { ucent A = 40532432168321451235829354323; }
//	//assertStaticAndRuntime!(toXML(new UCentField()) == `{"A":40532432168321451235829354323}`, "Failed to correctly serialize a ucent field!");
//	//assertStaticAndRuntime!(fromXML!UCentField(`{"A":40532432168321451235829354323}`).A == 40532432168321451235829354323, "Failed to correctly deserialize a ucent field!");
//	//assertStaticAndRuntime!(fromXML!UCentField(`{"A":"40532432168321451235829354323"}`).A == 40532432168321451235829354323, "Failed to correctly deserialize a ucent field set to the quoted value '40532432168321451235829354323'!");
//	
//	// TODO: Test NaN and infinite support.
//	// TODO: Why on earth does this have no decimals???
//	@serializable static class FloatField { float A = -433200; }
//	// TODO: Make this static once float -> string conversion is possible in CTFE
//	assert(toXML(new FloatField()) == `{"A":-433200}`, "Failed to correctly serialize a float field!");
//	assertStaticAndRuntime!(fromXML!FloatField(`{"A":-433200}`).A == -433200, "Failed to correctly deserialize a float field!");
//	assertStaticAndRuntime!(fromXML!FloatField(`{"A":"-433200"}`).A == -433200, "Failed to correctly deserialize a float field set to the quoted value '-433200'!");
//	
//	@serializable static class DoubleField { double A = 3.25432e+53; }
//	// TODO: Make this static once double -> string conversion is possible in CTFE
//	assert(toXML(new DoubleField()) == `{"A":3.25432e+53}`, "Failed to correctly serialize a double field!");
//	assertStaticAndRuntime!(fromXML!DoubleField(`{"A":3.25432e+53}`).A == 3.25432e+53, "Failed to correctly deserialize a double field!");
//	assertStaticAndRuntime!(fromXML!DoubleField(`{"A":"3.25432e+53"}`).A == 3.25432e+53, "Failed to correctly deserialize a double field set to the quoted value '3.25432e+53'!");
//	
//	@serializable static class RealField { real A = -2.13954e+104; }
//	// TODO: Make this static once real -> string conversion is possible in CTFE
//	assert(toXML(new RealField()) == `{"A":-2.13954e+104}`, "Failed to correctly serialize a real field!");
//	assertStaticAndRuntime!(fromXML!RealField(`{"A":-2.13954e+104}`).A == -2.13954e+104, "Failed to correctly deserialize a real field!");
//	assertStaticAndRuntime!(fromXML!RealField(`{"A":"-2.13954e+104"}`).A == -2.13954e+104, "Failed to correctly deserialize a real field set to the quoted value '-2.13954e+104'!");
//	
//	@serializable static class CharField { char A = '\x05'; }
//	assertStaticAndRuntime!(toXML(new CharField()) == `{"A":"\u0005"}`, "Failed to correctly serialize a char field!");
//	assertStaticAndRuntime!(fromXML!CharField(`{"A":"\u0005"}`).A == '\x05', "Failed to correctly deserialize a char field!");
//	
//	@serializable static class WCharField { wchar A = '\u04DA'; }
//	assertStaticAndRuntime!(toXML(new WCharField()) == `{"A":"\u04DA"}`, "Failed to correctly serialize a wchar field!");
//	assertStaticAndRuntime!(fromXML!WCharField(`{"A":"\u04DA"}`).A == '\u04DA', "Failed to correctly deserialize a wchar field!");
//	
//	@serializable static class DCharField { dchar A = '\U0010FFFF'; }
//	assertStaticAndRuntime!(toXML(new DCharField()) == `{"A":"\x0010FFFF"}`, "Failed to correctly serialize a dchar field!");
//	assertStaticAndRuntime!(fromXML!DCharField(`{"A":"\x0010FFFF"}`).A == '\U0010FFFF', "Failed to correctly deserialize a dchar field!");
//	
//	@serializable static class StringField { string A = "Hello!\b\"\u08A8\U0010FFFF"; }
//	assertStaticAndRuntime!(toXML(new StringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a string field!");
//	assertStaticAndRuntime!(fromXML!StringField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A == "Hello!\b\"\u08A8\U0010FFFF", "Failed to correctly deserialize a string field!");
//	
//	@serializable static class WStringField { wstring A = "Hello!\b\"\u08A8\U0010FFFF"w; }
//	assertStaticAndRuntime!(toXML(new WStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wstring field!");
//	assertStaticAndRuntime!(fromXML!WStringField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A == "Hello!\b\"\u08A8\U0010FFFF"w, "Failed to correctly deserialize a wstring field!");
//	
//	() @trusted {
//		@serializable static class WCharArrayField { wchar[] A = cast(wchar[])"Hello!\b\"\u08A8\U0010FFFF"w; }
//		assertStaticAndRuntime!(toXML(new WCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a wchar[] field!");
//		assertStaticAndRuntime!(fromXML!WCharArrayField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A.equal(cast(wchar[])"Hello!\b\"\u08A8\U0010FFFF"w), "Failed to correctly deserialize a wchar[] field!");
//	}();
//	
//	@serializable static class ConstWCharArrayField { const(wchar)[] A = "Hello!\b\"\u08A8\U0010FFFF"w; }
//	assertStaticAndRuntime!(toXML(new ConstWCharArrayField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a const(wchar)[] field!");
//	assertStaticAndRuntime!(fromXML!ConstWCharArrayField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A.equal("Hello!\b\"\u08A8\U0010FFFF"w), "Failed to correctly deserialize a const(wchar)[] field!");
//	
//	@serializable static class DStringField { dstring A = "Hello!\b\"\u08A8\U0010FFFF"d; }
//	assertStaticAndRuntime!(toXML(new DStringField()) == `{"A":"Hello!\b\"\u08A8\x0010FFFF"}`, "Failed to correctly serialize a dstring field!");
//	assertStaticAndRuntime!(fromXML!DStringField(`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`).A == "Hello!\b\"\u08A8\U0010FFFF"d, "Failed to correctly deserialize a dstring field!");
//	
//	@serializable static class FalseBoolField { bool A; auto Init() { A = false; return this; } }
//	assertStaticAndRuntime!(toXML((new FalseBoolField()).Init()) == `{"A":false}`, "Failed to correctly serialize a bool field set to false!");
//	assertStaticAndRuntime!(fromXML!FalseBoolField(`{"A":false}`).A == false, "Failed to correctly deserialize a bool field set to false!");
//	assertStaticAndRuntime!(fromXML!FalseBoolField(`{"A":"false"}`).A == false, "Failed to correctly deserialize a bool field set to the quoted value 'false'!");
//	
//	@serializable static class TrueBoolField { bool A; auto Init() { A = true; return this; } }
//	assertStaticAndRuntime!(toXML((new TrueBoolField()).Init()) == `{"A":true}`, "Failed to correctly serialize a bool field set to true!");
//	assertStaticAndRuntime!(fromXML!TrueBoolField(`{"A":true}`).A == true, "Failed to correctly deserialize a bool field set to true!");
//	assertStaticAndRuntime!(fromXML!TrueBoolField(`{"A":"true"}`).A == true, "Failed to correctly deserialize a bool field set to the quoted value 'true'!");
//	assertStaticAndRuntime!(fromXML!TrueBoolField(`{"A":"True"}`).A == true, "Failed to correctly deserialize a bool field set to the quoted value 'True'!");
//	assertStaticAndRuntime!(fromXML!TrueBoolField(`{"A":"tRUe"}`).A == true, "Failed to correctly deserialize a bool field set to the quoted value 'tRUe'!");
//	
//	@serializable static class NullObjectField { Object A = null; }
//	assertStaticAndRuntime!(toXML(new NullObjectField()) == `{"A":null}`, "Failed to correctly serialize an Object field set to null!");
//	assertStaticAndRuntime!(fromXML!NullObjectField(`{"A":null}`).A is null, "Failed to correctly deserialize an Object field set to null!"); 
//	assertStaticAndRuntime!(fromXML!NullObjectField(`{"A":"null"}`).A is null, "Failed to correctly deserialize an Object field set to the quoted value 'null'!"); 
//	
//	@serializable static class ClassField { SerializeAsField A = new SerializeAsField(); }
//	assertStaticAndRuntime!(toXML(new ClassField()) == `{"A":{"A":3,"D":5}}`, "Failed to correctly serialize a class field!");
//	assertStaticAndRuntime!(() {
//		auto cfa = fromXML!ClassField(`{"A":{"A":3,"D":5}}`);
//		assert(cfa.A);
//		assert(cfa.A.A == 3);
//		assert(cfa.A.B == 5);
//		assert(cfa.A.D == 7);
//		return true;
//	}(), "Failed to correctly deserialize a class field!");
//	
//	@serializable static class ClassArrayField { SerializeAsField[] A = [new SerializeAsField(), new SerializeAsField()]; }
//	assertStaticAndRuntime!(toXML(new ClassArrayField()) == `{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`, "Failed to correctly serialize a class array field!");
//	assertStaticAndRuntime!(() {
//		auto cfa = fromXML!ClassArrayField(`{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`);
//		assert(cfa.A);
//		assert(cfa.A.length == 2);
//		assert(cfa.A[0].A == 3);
//		assert(cfa.A[0].B == 5);
//		assert(cfa.A[1].A == 3);
//		assert(cfa.A[1].B == 5);
//		return true;
//	}(), "Failed to correctly deserialize a class array field!");
//	
//	@serializable static class IntArrayField { int[] A = [-3, 6, 190]; }
//	assertStaticAndRuntime!(toXML(new IntArrayField()) == `{"A":[-3,6,190]}`, "Failed to correctly serialize an int[] field!");
//	assertStaticAndRuntime!(fromXML!IntArrayField(`{"A":[-3,6,190]}`).A.equal([-3, 6, 190]), "Failed to correctly deserialize an int[] field!");
//	
//	@serializable static struct StructParent { int A = 3; }
//	assertStaticAndRuntime!(StructParent().toXML() == `{"A":3}`, "Failed to correctly serialize a structure!");
//	assertStaticAndRuntime!(fromXML!StructParent(`{"A":3}`).A == 3, "Failed to correctly deserialize a structure!");
//	
//	@serializable static struct StructField { StructParent A; }
//	assertStaticAndRuntime!(StructField().toXML() == `{"A":{"A":3}}`, "Failed to correctly serialize a struct field!");
//	assertStaticAndRuntime!(fromXML!StructField(`{"A":{"A":4}}`).A.A == 4, "Failed to correctly deserialize a struct field!");
//	
//	static class ParsableClass 
//	{
//		import std.conv : to;
//		
//		int A = 3;
//		
//		override string toString() @safe pure { return to!string(A); }
//		static typeof(this) parse(string str) @safe pure
//		{
//			auto p = new ParsableClass();
//			p.A = to!int(str);
//			return p;
//		}
//	}
//	@serializable static class ParsableClassField { ParsableClass A = new ParsableClass(); }
//	assertStaticAndRuntime!(new ParsableClassField().toXML() == `{"A":"3"}`, "Failed to correctly serialize a non-serializable parsable class!");
//	assertStaticAndRuntime!(fromXML!ParsableClassField(`{"A":"5"}`).A.A == 5, "Failed to correctly deserialize a non-serializable parsable class!");
//	
//	enum EnumTest { valA, valB, valC }
//	@serializable static class EnumField { EnumTest A = EnumTest.valB; }
//	assertStaticAndRuntime!(new EnumField().toXML() == `{"A":"valB"}`, "Failed to correctly serialize an enum!");
//	assertStaticAndRuntime!(fromXML!EnumField(`{"A":"valB"}`).A == EnumTest.valB, "Failed to correctly deserialize an enum!");
}