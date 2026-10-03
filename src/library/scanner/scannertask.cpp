#include "library/scanner/scannertask.h"

#include "moc_scannertask.cpp"

ScannerTask::ScannerTask(LibraryScanner* pScanner,
                         const ScannerGlobalPointer scannerGlobal)
        : m_pScanner(pScanner),
          m_scannerGlobal(scannerGlobal),
          m_success(false) {
    setAutoDelete(true);
}

ScannerTask::~ScannerTask() {
    if (m_scannerGlobal) {
        // Tasks may outlive the ScannerGlobal they were created with
        // when the scanner is torn down while queued tasks still exist.
        if (!m_success) {
            m_scannerGlobal->clearScanFinishedCleanly();
        }
        m_scannerGlobal->getTaskWatcher().taskDone();
    }
}
