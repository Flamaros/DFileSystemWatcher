#include "main.h"

#include <QCoreApplication>

#include <QMutex>
#include <QFile>
#include <QFileInfo>

#include <windows.h>

QMutex	mutex;
bool	running = true;
QString	path;

void	WatchingLoop::run()
{
    HANDLE directoryHandle = CreateFileW(path.toStdWString().c_str(),
                                         FILE_LIST_DIRECTORY,
                                         FILE_SHARE_READ | FILE_SHARE_WRITE,	// We don't allow deletation or renaming of this directory during the watch.
                                         nullptr,
                                         OPEN_EXISTING,					        // It's not valid to create a directory with CreateFile, but in our case that not the goal so everything is good here.
                                         FILE_FLAG_BACKUP_SEMANTICS |	        // FILE_FLAG_BACKUP_SEMANTICS to obtain a directory handle (used later by ReadDirectoryChanges).
                                             FILE_FLAG_OVERLAPPED,			    // FILE_FLAG_OVERLAPPED need to be specified when an OVERLAPPED structure is used with ReadDirectoryChanges.
                                         nullptr);

    // TODO create the io completion port here

    FILE_NOTIFY_INFORMATION         buffer[512];
    OVERLAPPED                      overlapped;
    BOOL                            readDirectoryResult;

    Q_ASSERT(sizeof(buffer) < 64 * 1000 * 1024);	// From official documentation : ReadDirectoryChangesW fails with ERROR_INVALID_PARAMETER when the buffer length is greater than 64 KB and the application is monitoring a directory over the network. This is due to a packet size limitation with the underlying file sharing protocols.
    Q_ASSERT((uint)buffer % sizeof(DWORD) == 0);    // buffer must be DWORD aligned

    memset(&overlapped, 0, sizeof(overlapped));

    overlapped.hEvent = CreateEventW(nullptr,
                                     false,
                                     true,
                                     nullptr);

    for (uint i = 0; true; i++)
    {
        mutex.lock();
        if (running == false)
        {
            mutex.unlock();
            break;
        }
        mutex.unlock();

        readDirectoryResult = ReadDirectoryChangesW(directoryHandle,
                                                    &buffer[0],
                                                    sizeof(buffer),
                                                    true,
                                                    FILE_NOTIFY_CHANGE_FILE_NAME |
                                                        FILE_NOTIFY_CHANGE_DIR_NAME |
                                                        FILE_NOTIFY_CHANGE_ATTRIBUTES |
                                                        FILE_NOTIFY_CHANGE_SIZE |
                                                        FILE_NOTIFY_CHANGE_LAST_WRITE |
                                                        FILE_NOTIFY_CHANGE_LAST_ACCESS |
                                                        FILE_NOTIFY_CHANGE_CREATION |
                                                        FILE_NOTIFY_CHANGE_SECURITY,
                                                    nullptr,
                                                    &overlapped,
                                                    nullptr);  // TODO use the io completion port here

        if (readDirectoryResult == false)
        {
            printf("Error : Failed to read directory.\n");
            switch (GetLastError())
            {
                case ERROR_INVALID_FUNCTION:
                    printf("\tTarget file system does not support this operation.\n");
                    break;
                default:
                    printf("\tError : ReadDirectoryChangesW - code : %ld.\n", GetLastError());
                    break;
            }
            Sleep(50);
            continue;
        }

        BOOL    getOverlappedResultResult;
        DWORD	numberOfBytesTransferred;

        // It seems I am loosing watching capabilities during threatement of previous data

        getOverlappedResultResult = GetOverlappedResult(directoryHandle,
                            &overlapped,
                            &numberOfBytesTransferred,
                            false);

        if (getOverlappedResultResult)
        {
            printf("%ld %d\n", numberOfBytesTransferred, sizeof(FILE_NOTIFY_INFORMATION));

            if (numberOfBytesTransferred > 0)
            {
                FILE_NOTIFY_INFORMATION*	info;
                size_t						offset = 0;

                do
                {
                    info = &buffer[0] + offset;

                    WCHAR*  fileName;

                    fileName = new WCHAR[info->FileNameLength / sizeof(WCHAR) + 1];
                    memcpy(fileName, &info->FileName[0], info->FileNameLength);
                    fileName[info->FileNameLength / sizeof(WCHAR)] = 0;

                    printf("File \"%s\" was modified by following operation:\n", QString::fromWCharArray(fileName).toUtf8().data());

                    switch (info->Action)
                    {
                        case FILE_ACTION_ADDED:
                            printf("\tAdded\n");
                            break;
                        case FILE_ACTION_REMOVED:
                            printf("\tRemoved\n");
                            break;
                        case FILE_ACTION_MODIFIED:
                            printf("\tModified\n");
                            break;
                        case FILE_ACTION_RENAMED_OLD_NAME:
                            printf("\tRename (old name)\n");
                            break;
                        case FILE_ACTION_RENAMED_NEW_NAME:
                            printf("\tRename (new name)\n");
                            break;
                    }
                    offset = info->NextEntryOffset;

                    delete[] fileName;
                }
                while (offset != 0);
            }
        }
/*            else
        {
            printf("\tError : GetOverlappedResult - code : %d.", GetLastError());
        }
*/
//			Sleep(50);
    }

    CloseHandle(directoryHandle);
    directoryHandle = INVALID_HANDLE_VALUE;
}

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);

//    return a.exec();


    path = QCoreApplication::applicationDirPath();

    // Opening the directory
    if (QFileInfo::exists(path) == false)
        return -1;

    // TODO Check the directory isn't already watched


    WatchingLoop watchingLoopThread;

    watchingLoopThread.start();

    Sleep(200);	// TO be sure the thread have time to make the initialization of the watcher

    // Doing some file operations in the folder watched
    QFile   file(path + "/new_file.txt");

    file.open(QIODevice::WriteOnly);
    file.write("foo");	// Will normally throw a creation and a file size modification
    file.close();
    file.remove();
    // --

//    printf("Press any key to exit!\n");
//    system("PAUSE");

    mutex.lock();
    running = false;
    mutex.unlock();

    watchingLoopThread.wait();

    return 0;
}
