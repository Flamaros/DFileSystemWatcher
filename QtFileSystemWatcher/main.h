#pragma once

#include <QThread>

class WatchingLoop : public QThread
{
    Q_OBJECT
public:

private:
    void run() Q_DECL_OVERRIDE;
};
