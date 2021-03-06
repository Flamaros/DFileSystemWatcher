// Written in the D programming language.

/**
TODO :
 - Windows : Faire des threads en plus du iocompletion port, attention au thread pour le call des signaux
 - Linux : Utiliser inotify
*/


/**
Utilities to monitor modifications on specified paths of the file system. This
module use IO completion port to support tracking of a very large number of
path. To be able to propagate events efficiently signals are used.

Copyright: Copyright © 2015 Xavier Bigand.
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   Xavier Bigand
*/
module filesystemwatcher;

import std.file;
import std.string;
import std.signals;

version (Windows)
{
	public import filesystemwatcher_win32;

	alias FileSystemWatcherWin32	FileSystemWatcher;
}

interface FileSystemWatcherInterface
{
	/********************************************
	Adds path to the file system watcher if path exists. The path is not added
	if it does not exist. 
	If path specifies a directory, the directoryChanged() signal will be emitted
	when path is modified or removed from disk; otherwise the fileChanged()
	signal is emitted when path is modified, renamed or removed.

	Returns: True on success, if the file is already in the file system watcher
	it acts like a success.

	Throws: 
    Params:
	path            = Path to an existing file or directory to watch

	Examples:
	--------------------
	--------------------
	*/
	bool addPath(in string path);
	string[] addPaths(in string[] path);
	string[] directories() const;
	string[] files() const;
	bool removePath(in string path);
	string[] removePaths(in string[] path);
}
