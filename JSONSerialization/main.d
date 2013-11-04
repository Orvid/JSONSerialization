module main;

import std.stdio;
import std.datetime : StopWatch;
import std.serialization : serializable;
import std.json : toJSON, fromJSON;
import std.conv : to;
import std.range : isOutputRange;
import std.performance.array : Appender;

enum ObjectCount = 100000;

void main(string[] args)
{
	@serializable static final class SimpleObject
	{
		int id;
		string name;
		string address;
		int[] scores;

		public static SimpleObject Create(int id)
		{
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
	string[ObjectCount] stringArray;
	SimpleObject[ObjectCount] sourceArray;
	SimpleObject[ObjectCount] destinationArray;
	for (auto i = 0; i < ObjectCount; i++)
		sourceArray[i] = SimpleObject.Create(i);

	size_t totalPayload = 0;
	StopWatch swSerialize;
	auto ret = Appender!string();
	foreach (i, so; sourceArray)
	{
		swSerialize.start();
		toJSON(so, ret);
		swSerialize.stop();
		totalPayload += ret.data.length;
		stringArray[i] = ret.data;
		ret.clear();
	}

	StopWatch swDeserialize;
	foreach (i, str; stringArray)
	{
		swDeserialize.start();
		destinationArray[i] = fromJSON!SimpleObject(str);
		swDeserialize.stop();
	}

	writefln("Took %s ms (%s ms / %s/sec) to serialize 100k SimpleObjects with an average payload of %s bytes (%s).", swSerialize.peek().msecs, cast(real)swSerialize.peek().msecs / ObjectCount, cast(real)ObjectCount * (1000.0 / swSerialize.peek().msecs), cast(real)totalPayload / ObjectCount, totalPayload);
	writefln("Took %s ms (%s ms / %s/sec) to deserialize 100k SimpleObjects", swDeserialize.peek().msecs, cast(real)swDeserialize.peek().msecs / ObjectCount, cast(real)ObjectCount * (1000.0 / swDeserialize.peek().msecs));
}

