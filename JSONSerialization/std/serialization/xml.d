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
	import std.serialization : runSerializationTests, Test;
	
	runSerializationTests!(string, toXML, fromXML, [
		Test.PrivateConstructor: [`{"B":5}`],
		Test.NonSerializable: [`{"B":5}`],
		Test.OptionalField: [`{"B":5}`],
		Test.NonSerializedField: [`{"A":3}`],
		Test.SerializeAsField: [`{"A":3,"D":5}`],
		Test.ByteField: [`{"A":-3}`, `{"A":"-3"}`],
		Test.UByteField: [`{"A":159}`, `{"A":"159"}`],
		Test.ShortField: [`{"A":-26125}`, `{"A":"-26125"}`],
		Test.UShortField: [`{"A":65313}`, `{"A":"65313"}`],
		Test.IntField: [`{"A":-2032534342}`, `{"A":"-2032534342"}`],
		Test.UIntField: [`{"A":2520041234}`, `{"A":"2520041234"}`],
		Test.LongField: [`{"A":-2305393212345134623}`, `{"A":"-2305393212345134623"}`],
		Test.ULongField: [`{"A":4021352154138321354}`, `{"A":"4021352154138321354"}`],
		Test.CentField: [`{"A":-23932104152349231532145324134}`, `{"A":"-23932104152349231532145324134"}`],
		Test.UCentField: [`{"A":40532432168321451235829354323}`, `{"A":"40532432168321451235829354323"}`],
		Test.FloatField: [`{"A":-433200}`, `{"A":"-433200"}`],
		Test.DoubleField: [`{"A":3.25432e+53}`, `{"A":"3.25432e+53"}`],
		Test.RealField: [`{"A":-2.13954e+104}`, `{"A":"-2.13954e+104"}`],
		Test.CharField: [`{"A":"\u0005"}`],
		Test.WCharField: [`{"A":"\u04DA"}`],
		Test.DCharField: [`{"A":"\x0010FFFF"}`],
		Test.StringField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.WStringField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.WCharArrayField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.ConstWCharArrayField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.DStringField: [`{"A":"Hello!\b\"\u08A8\x0010FFFF"}`],
		Test.FalseBoolField: [`{"A":false}`, `{"A":"false"}`],
		Test.TrueBoolField: [`{"A":true}`, `{"A":"true"}`, `{"A":"True"}`, `{"A":"tRUe"}`],
		Test.NullObjectField: [`{"A":null}`, `{"A":"null"}`],
		Test.ClassField: [`{"A":{"A":3,"D":5}}`],
		Test.ClassArrayField: [`{"A":[{"A":3,"D":5},{"A":3,"D":5}]}`],
		Test.IntArrayField: [`{"A":[-3,6,190]}`],
		Test.StructParent: [`{"A":3}`],
		Test.StructField: [`{"A":{"A":3}}`],
		Test.ParsableClassField: [`{"A":"3"}`],
		Test.EnumField: [`{"A":"valB"}`],
	])();
}