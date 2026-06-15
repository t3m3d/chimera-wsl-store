//
//    Copyright (C) Microsoft.  All rights reserved.
// Licensed under the terms described in the LICENSE file in the root of this project.
//

#include "stdafx.h"

bool DistributionInfo::CreateUser(std::wstring_view userName)
{
    DWORD exitCode;

    // Create the user account with home dir, wheel group (for doas), users
    // group, and bash as the login shell. Chimera ships shadow's useradd in
    // /usr/sbin/, not Debian's adduser.
    std::wstring commandLine = L"/usr/sbin/useradd -m -G wheel,users -s /bin/bash ";
    commandLine += userName;
    HRESULT hr = g_wslApi.WslLaunchInteractive(commandLine.c_str(), true, &exitCode);
    if ((FAILED(hr)) || (exitCode != 0)) {
        return false;
    }

    // Set the password interactively.
    commandLine = L"/usr/sbin/passwd ";
    commandLine += userName;
    hr = g_wslApi.WslLaunchInteractive(commandLine.c_str(), true, &exitCode);
    if ((FAILED(hr)) || (exitCode != 0)) {
        // Roll back: delete the half-created user.
        commandLine = L"/usr/sbin/userdel -r ";
        commandLine += userName;
        g_wslApi.WslLaunchInteractive(commandLine.c_str(), true, &exitCode);
        return false;
    }

    // Chimera uses doas (OpenBSD's lighter sudo) instead of sudo. Wire wheel
    // -> doas so the user can run privileged commands. Idempotent on re-runs.
    g_wslApi.WslLaunchInteractive(
        L"/bin/sh -c \"echo 'permit persist :wheel' > /etc/doas.conf && chmod 0400 /etc/doas.conf\"",
        true, &exitCode);

    return true;
}

ULONG DistributionInfo::QueryUid(std::wstring_view userName)
{
    HANDLE readPipe;
    HANDLE writePipe;
    SECURITY_ATTRIBUTES sa{sizeof(sa), nullptr, true};
    ULONG uid = UID_INVALID;
    if (CreatePipe(&readPipe, &writePipe, &sa, 0)) {
        std::wstring command = L"/usr/bin/id -u ";
        command += userName;
        int returnValue = 0;
        HANDLE child;
        HRESULT hr = g_wslApi.WslLaunch(command.c_str(), true, GetStdHandle(STD_INPUT_HANDLE), writePipe, GetStdHandle(STD_ERROR_HANDLE), &child);
        if (SUCCEEDED(hr)) {
            WaitForSingleObject(child, INFINITE);
            DWORD exitCode;
            if ((GetExitCodeProcess(child, &exitCode) == false) || (exitCode != 0)) {
                hr = E_INVALIDARG;
            }

            CloseHandle(child);
            if (SUCCEEDED(hr)) {
                char buffer[64];
                DWORD bytesRead;

                if (ReadFile(readPipe, buffer, (sizeof(buffer) - 1), &bytesRead, nullptr)) {
                    buffer[bytesRead] = ANSI_NULL;
                    try {
                        uid = std::stoul(buffer, nullptr, 10);
                    } catch( ... ) { }
                }
            }
        }

        CloseHandle(readPipe);
        CloseHandle(writePipe);
    }

    return uid;
}
