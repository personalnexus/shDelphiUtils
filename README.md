# shDelphiUtils

This is a collection of Delphi utilities that I have written over approximately 20 years of coding in Delphi. Be warned that the latest version of Delphi that I used to do serious development was Delphi 2007. So most of the code you'll find here is of that era. I upgraded some classes with generics using Delphi XE, but that's about it.

The unit structure aligns with my [C# utilities solution](https://github.com/personalnexus/ShUtilities). The coding style is the one Borland recommended for Delphi (way back when) with some influences from my C# coding.

Unlike my C# utilities, which are very representative of how I write production code, this repo is more experimental with very little tests and even fewer guarantuees that the code does what it says it does.

## Collections

* __TConcurrentQueue__: Experimental queue for use with multiple reader- and writer-threads without locking. Uses Interlocked operations for synchronization.
* __TSet__: Basic set implementation based on TDictionary.
* __TTrie__: Experimental Trie implementation with support for a reduced set of possible key elements to minimize space requirements.
* __TTrieDictionary__: Experimental IDictionary implementation that combines an array for single character keys with a TTrie for short keys and finally a TDictionary for long keys

## Media

* __TVolumeMonitor__: Monitors the current volume against a given target volume and reports and/or adjusts the current volume to match the target.