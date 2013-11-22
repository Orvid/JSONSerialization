module main;

import core.memory : GC;

import std.datetime : StopWatch;
import std.performance.array : Appender;
import std.serialization : serializable;
import std.serialization.bson : fromBSON, toBSON;
import std.serialization.json : fromJSON, toJSON;
import std.serialization.xml : fromXML, toXML;
import std.stdio;

enum ObjectCount = 100000;

@serializable final class SimpleObject
{
	int id;
	string name;
	string address;
	int[] scores;
	
	public static SimpleObject Create(int id)
	{
		import std.conv : to;
		import std.random : uniform;
		
		auto so = new SimpleObject();
		so.id = uniform(0, ObjectCount);
		so.name = "Simple-" ~ to!string(id);
		so.address = "Planet Earth";
		auto scoreCount = uniform(0, 10);
		for (auto i = 0; i < scoreCount; i++)
		{
			// This is a uniform random with a uniform bias torward 0, to produce more realistic
			// data as input. (as most data has a tendancy to group torwards 0)
			so.scores ~= uniform(uniform(int.min, 0), uniform(0, int.max));
		}
		return so;
	}
}

// serializeFunc must be of the type `void function(SimpleObject a, ref Appender!(ubyte[]) ret)`
// deserializeFunc must be of the type `SimpleObject function(ubyte[] val)`
static void runBenchmark(string serializationFormatName, alias serializeFunc, alias deserializeFunc)(ref SimpleObject[] sourceArray, ref ubyte[][] intermediateArray, ref SimpleObject[] destinationArray)
{
	writeln(serializationFormatName, ':');
	
	size_t totalPayload = 0;
	StopWatch swSerialize;
	auto ret = Appender!(ubyte[])();
	foreach (i, so; sourceArray)
	{
		swSerialize.start();
		serializeFunc(so, ret);
		swSerialize.stop();
		intermediateArray[i] = ret.data;
		totalPayload += intermediateArray[i].length;
		ret.clear();
	}
	writefln("\tTook %s ms (%s ms / %s/sec) to serialize 100k SimpleObjects with an average payload of %s bytes (%s).", swSerialize.peek().msecs, cast(real)swSerialize.peek().msecs / ObjectCount, cast(ulong)(cast(real)ObjectCount * (1000.0 / swSerialize.peek().msecs)), cast(real)totalPayload / ObjectCount, totalPayload);
	
	StopWatch swDeserialize;
	foreach (i, val; intermediateArray)
	{
		swDeserialize.start();
		destinationArray[i] = deserializeFunc(val);
		swDeserialize.stop();
	}

	writefln("\tTook %s ms (%s ms / %s/sec) to deserialize 100k SimpleObjects", swDeserialize.peek().msecs, cast(real)swDeserialize.peek().msecs / ObjectCount, cast(ulong)(cast(real)ObjectCount * (1000.0 / swDeserialize.peek().msecs)));
	writeln();
	
	intermediateArray[] = null;
	destinationArray[] = null;
	GC.collect();
}

void main(string[] args)
{
	GC.disable();

	ubyte[][] intermediateArray = new ubyte[][ObjectCount];
	SimpleObject[] sourceArray = new SimpleObject[ObjectCount];
	SimpleObject[] destinationArray = new SimpleObject[ObjectCount];
	for (auto i = 0; i < ObjectCount; i++)
		sourceArray[i] = SimpleObject.Create(i);
	GC.collect();

	runBenchmark!("JSON", (so, ref ret) => toJSON(so, ret), (val) => fromJSON!SimpleObject(cast(string)val))(sourceArray, intermediateArray, destinationArray);
	runBenchmark!("BSON", (so, ref ret) => toBSON(so, ret), (val) => fromBSON!SimpleObject(val))(sourceArray, intermediateArray, destinationArray);
	runBenchmark!("XML",  (so, ref ret) => toXML(so, ret),  (val) => fromXML!SimpleObject(cast(string)val))(sourceArray, intermediateArray, destinationArray);
}

