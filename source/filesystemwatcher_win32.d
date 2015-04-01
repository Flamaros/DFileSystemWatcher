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
module filesystemwatcher_win32;

import std.file;
import std.path;
import std.string;
import std.signals;
import core.thread;
import core.stdc.string : memset, memcpy;
import core.sync.mutex;

import filesystemwatcher;

import bindings.win32;

class FileSystemWatcherWin32 : FileSystemWatcherInterface
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
	bool addPath(in string path)
	{
		return false;
	}

	string[] addPaths(in string[] path)
	{
		string[]	failedPaths;

		return failedPaths;
	}

	string[] directories() const
	{
		string[]	directories;

		return directories;
	}

	string[] files() const
	{
		string[]	files;

		return files;
	}

	bool removePath(in string path)
	{
		return false;
	}

	string[] removePaths(in string[] path)
	{
		string[]	failedPaths;

		return failedPaths;
	}
}

import std.stdio;
import std.process;
import std.conv;

// https://msdn.microsoft.com/en-us/library/windows/desktop/aa365465%28v=vs.85%29.aspx

unittest
{
	Mutex	mutex = new Mutex;
	bool	running = true;

	string	path = dirName(thisExePath());

	// Opening the directory
	if (isDir(path) == false)
		return;

	// TODO Check the directory isn't already watched

	void	watchingLoop()
	{
		HANDLE directoryHandle = CreateFileW(to!(wchar[])(path).ptr,
											 FILE_LIST_DIRECTORY, 
											 FILE_SHARE_READ | FILE_SHARE_WRITE,	// We don't allow deletation or renaming of this directory during the watch.
											 null,
											 OPEN_EXISTING,					        // It's not valid to create a directory with CreateFile, but in our case that not the goal so everything is good here.
											 FILE_FLAG_BACKUP_SEMANTICS |	        // FILE_FLAG_BACKUP_SEMANTICS to obtain a directory handle (used later by ReadDirectoryChanges).
												 FILE_FLAG_OVERLAPPED,			    // FILE_FLAG_OVERLAPPED need to be specified when an OVERLAPPED structure is used with ReadDirectoryChanges.
											 null);

		// TODO create the io completion port here

		FILE_NOTIFY_INFORMATION[512]    buffer;
		OVERLAPPED                      overlapped;
		BOOL                            readDirectoryResult;

		assert(buffer.sizeof < 64 * 1000 * 1024);	// From official documentation : ReadDirectoryChangesW fails with ERROR_INVALID_PARAMETER when the buffer length is greater than 64 KB and the application is monitoring a directory over the network. This is due to a packet size limitation with the underlying file sharing protocols.

		memset(&overlapped, 0, overlapped.sizeof);

		// TODO Need initialize overlapped.hEvent ?
		// Be sure to set the hEvent member of the OVERLAPPED structure to a unique event.

		readDirectoryResult = ReadDirectoryChangesW(directoryHandle,
													&buffer[0],
													buffer.sizeof,
													true,
													FILE_NOTIFY_CHANGE_FILE_NAME |
														FILE_NOTIFY_CHANGE_DIR_NAME |
														FILE_NOTIFY_CHANGE_ATTRIBUTES |
														FILE_NOTIFY_CHANGE_SIZE |
														FILE_NOTIFY_CHANGE_LAST_WRITE |
														FILE_NOTIFY_CHANGE_LAST_ACCESS |
														FILE_NOTIFY_CHANGE_CREATION |
														FILE_NOTIFY_CHANGE_SECURITY,
													null,
													&overlapped,
													null);  // TODO use the io completion port here

		if (readDirectoryResult == false)
		{
			writeln("Error : Failed to read directory.");
			switch (GetLastError())
			{
				case ERROR_INVALID_FUNCTION:
					writeln("\tTarget file system does not support this operation.");
					break;
				default:
					break;
			}
			return;
		}

		while (true)
		{
			synchronized (mutex)
				if (running == false)
					break;

			BOOL    getOverlappedResultResult;
			DWORD	numberOfBytesTransferred;

			getOverlappedResultResult = GetOverlappedResult(directoryHandle,
								&overlapped,
								&numberOfBytesTransferred,
								false);

			if (getOverlappedResultResult)
			{
				writefln("%d %d", numberOfBytesTransferred, FILE_NOTIFY_INFORMATION.sizeof);

				if (numberOfBytesTransferred > 0)
				{
					FILE_NOTIFY_INFORMATION*	info;
					size_t						offset = 0;

					do
					{
						info = &buffer[0] + offset;

						wchar[]	fileName;

						fileName.length = info.FileNameLength / WCHAR.sizeof;
						memcpy(fileName.ptr, &info.FileName[0], info.FileNameLength);
						*(fileName.ptr + info.FileNameLength) = 0;

						writefln("File \"%s\" was modified by following operation:", fileName);

						final switch (info.Action)
						{
							case FILE_ACTION_ADDED:
								writeln("\tAdded");
								break;
							case FILE_ACTION_REMOVED:
								writeln("\tRemoved");
								break;
							case FILE_ACTION_MODIFIED:
								writeln("\tModified");
								break;
							case FILE_ACTION_RENAMED_OLD_NAME:
								writeln("\tRename (old name)");
								break;
							case FILE_ACTION_RENAMED_NEW_NAME:
								writeln("\tRename (new name)");
								break;
						}
						offset = info.NextEntryOffset;
					}
					while (offset != 0);

					readDirectoryResult = ReadDirectoryChangesW(directoryHandle,
																&buffer[0],
																buffer.sizeof,
																true,
																FILE_NOTIFY_CHANGE_FILE_NAME |
																	FILE_NOTIFY_CHANGE_DIR_NAME |
																	FILE_NOTIFY_CHANGE_ATTRIBUTES |
																	FILE_NOTIFY_CHANGE_SIZE |
																	FILE_NOTIFY_CHANGE_LAST_WRITE |
																	FILE_NOTIFY_CHANGE_LAST_ACCESS |
																	FILE_NOTIFY_CHANGE_CREATION |
																	FILE_NOTIFY_CHANGE_SECURITY,
																null,
																&overlapped,
																null);  // TODO use the io completion port here
				}
			}

			Sleep(50);
		}

		CloseHandle(directoryHandle);
		directoryHandle = INVALID_HANDLE_VALUE;
	}

	Thread	watchingLoopThread = new Thread(&watchingLoop);

	watchingLoopThread.start();

	Sleep(200);	// TO be sure the thread have time to make the initialization of the watcher

	// Doing some file operations in the folder watched
	std.file.write(path ~ "/new_file.txt", "foo");	// Will normally throw a creation and a file size modification
	std.file.remove(path ~ "/new_file.txt");
	// --

	writeln("Press any key to exit!");
	executeShell("PAUSE");

	synchronized (mutex)
		running = false;
}
